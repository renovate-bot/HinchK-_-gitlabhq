# frozen_string_literal: true

require "fog/google"

# This script handles resources created during E2E test runs
#
# Delete: find all matching file pattern, read file and delete resources
# rake test_resources:delete[<file_pattern>]
#
# Upload: find all matching file pattern for failed test resources
# upload these files to GCS bucket `failed-test-resources` under specific environment name
# rake test_resources:upload[<file_pattern>,<ci_project_name>]
#
# Download: download JSON files under a given environment name (bucket directory)
# save to local under `tmp/`
# rake test_resources:download[<ci_project_name>]
#
# Required environment variables:
#   GITLAB_ADDRESS, required for delete task
#   GITLAB_QA_ACCESS_TOKEN, required for delete task
#   QA_TEST_RESOURCES_FILE_PATTERN, optional for delete task, required for upload task
#   QA_FAILED_TEST_RESOURCES_GCS_CREDENTIALS, required for upload task or download task

module QA
  module Tools
    class TestResourcesHandler
      include Support::API
      include Ci::Helpers

      IGNORED_RESOURCES = %w[
        QA::Resource::CiVariable
        QA::Resource::Repository::Commit
        QA::Resource::Design
        QA::Resource::InstanceOauthApplication
        QA::EE::Resource::ComplianceFramework
        QA::EE::Resource::GroupIteration
        QA::EE::Resource::Settings::Elasticsearch
        QA::EE::Resource::VulnerabilityItem
        QA::EE::Resource::SecurityScanPolicyProject
        QA::EE::Resource::ScanResultPolicyCommit
        QA::EE::Resource::InstanceAuditEventExternalDestination
      ].freeze

      PROJECT = 'gitlab-qa-resources'
      BUCKET  = 'failed-test-resources'

      def initialize(file_pattern = nil)
        @file_pattern = file_pattern
      end

      def run_delete
        failures = []
        files.flat_map do |file|
          resources = read_file(file)
          if resources.nil?
            logger.info("#{file} is empty, next...")
            next
          end

          filtered_resources = filter_resources(resources)
          if filtered_resources.nil?
            logger.info("No resources left to delete after filtering!")
            next
          end

          failures << delete_resources(filtered_resources)

          filtered_groups = filtered_resources['QA::Resource::Group']
          failures << delete_resources_permanently(filtered_groups, 'group') unless filtered_groups.nil?

          filtered_projects = filtered_resources['QA::Resource::Project']
          failures << delete_resources_permanently(filtered_projects, 'project') unless filtered_projects.nil?
        end

        return puts "\nDone" if failures.empty?

        puts "\nFailed to delete #{failures.size} resources:\n"
        puts failures
      end

      # Upload resources from failed test suites to GCS bucket
      # Files are organized by environment in which tests were executed
      #
      # E.g: staging/failed-test-resources-<randomhex>.json
      def upload(ci_project_name)
        if files.empty?
          logger.info("\nNothing to upload!")
          return
        end

        files.each do |file|
          file_name = "#{ci_project_name}/#{file.split('/').last}"
          logger.info("Uploading #{file_name}...")
          gcs_storage.put_object(BUCKET, file_name, File.read(file))
        end
      end

      # Download files from GCS bucket by environment name
      # Delete the files afterward
      def download(ci_project_name)
        logger.info("Downloading resource files from GCS for #{ci_project_name}...")
        bucket_items = gcs_storage.list_objects(BUCKET, prefix: "#{ci_project_name}/").items

        if bucket_items.blank?
          logger.info("\nNothing to download!")
          return
        end

        files_list = bucket_items.each_with_object([]) do |obj, arr|
          arr << obj.name
        end

        FileUtils.mkdir_p('tmp/')

        files_list.each do |file_name|
          local_path = "tmp/#{file_name.split('/').last}"
          logger.info("Downloading #{file_name} to #{local_path}")
          file = gcs_storage.get_object(BUCKET, file_name)
          File.write(local_path, file[:body])

          logger.info("Deleting #{file_name} from bucket")
          gcs_storage.delete_object(BUCKET, file_name)
        end
      end

      private

      def files
        logger.info('Gathering JSON files...')
        files = Dir.glob(@file_pattern)

        if files.empty?
          logger.info("There is no file with this pattern #{@file_pattern}")
          exit 0
        end

        files.reject! { |file| File.zero?(file) }

        if files.empty?
          logger.info("\nAll files were empty and rejected, nothing more to do!")
          exit 0
        end

        files
      end

      def read_file(file)
        logger.info("Reading and processing #{file}...")
        JSON.parse(File.read(file))
      rescue JSON::ParserError
        logger.error("Failed to read #{file} - Invalid format")
        nil
      end

      def filter_resources(resources)
        logger.info('Filtering resources - Only keep deletable resources...')

        transformed_values = resources.transform_values! do |v|
          v.reject do |attributes|
            attributes['info']&.match(/with full_path 'gitlab-qa-sandbox-group(-\d)?'/) ||
              attributes['http_method'] == 'get' && !attributes['info']&.include?("with username 'qa-") ||
              attributes['api_path'] == 'Cannot find resource API path'
          end
        end

        transformed_values.reject! { |k, v| v.empty? || IGNORED_RESOURCES.include?(k) }
      end

      def delete_resources(resources)
        resources.each_with_object([]) do |(key, value), failures|
          value.each do |resource|
            resource_info = resource['info'] ? "#{key} - #{resource['info']}" : "#{key} at #{resource['api_path']}"
            logger.info("Processing #{resource_info}...")

            if resource_not_found?(resource['api_path'])
              logger.info("#{resource['api_path']} returns 404, next...")
              next
            end

            delete_response = delete(Runtime::API::Request.new(api_client, resource['api_path']).url)

            if delete_response.code == 202 || delete_response.code == 204
              if key == 'QA::Resource::Group' || key == 'QA::Resource::Project' &&
                  !resource_not_found?(resource['api_path'])
                logger.info("Successfully marked #{resource_info} for deletion...")
              else
                logger.info("Deleting #{resource_info}... \e[32mSUCCESS\e[0m")
              end
            else
              logger.info("Deleting #{resource_info}... \e[31mFAILED - #{delete_response}\e[0m")
              # We might try to delete some groups or projects already marked for deletion
              # It's fine to ignore these failures
              failures << resource_info unless key == 'QA::Resource::Group' || key == 'QA::Resource::Project'
            end
          end
        end
      end

      def delete_resources_permanently(resources, type)
        resources.each_with_object([]) do |resource, failures|
          logger.info("Processing QA::Resource::#{type.capitalize} #{resource['info']}...")

          if resource_not_found?(resource['api_path'])
            logger.info("#{resource['api_path']} returns 404, next...")
            next
          end

          full_path = resource['info'].split("'").last

          if type == 'project'
            # We need to get the full path of the project again since marking it for deletion changes the name
            project_response = get(Runtime::API::Request.new(api_client, resource['api_path'].to_s).url)
            project = parse_body(project_response)
            full_path = project[:path_with_namespace]
          end

          permanent_delete_path = "#{resource['api_path']}?permanently_remove=true"\
                                  "&full_path=#{full_path}"
          response = delete(Runtime::API::Request.new(api_client, permanent_delete_path).url)

          if response.code == 202
            logger.info("Permanently deleting #{type} #{resource['info']}... \e[32mSUCCESS\e[0m")
          else
            logger.info("Permanently deleting #{type} #{resource['info']}... \e[31mFAILED - #{response}\e[0m")
            failures << "QA::Resource::#{type.capitalize} #{resource['info']}"
          end
        end
      end

      def resource_not_found?(api_path)
        # if api path contains param "?hard_delete=<boolean>", remove it
        get(Runtime::API::Request.new(api_client, api_path.split('?').first).url).code.eql? 404
      end

      def api_client
        abort("\nPlease provide GITLAB_ADDRESS") unless ENV['GITLAB_ADDRESS']

        @api_client ||= Runtime::API::Client.new(
          ENV['GITLAB_ADDRESS'],
          personal_access_token: personal_access_token
        )
      end

      def gcs_storage
        @gcs_storage ||= Fog::Storage::Google.new(
          google_project: PROJECT,
          **(File.exist?(json_key) ? { google_json_key_location: json_key } : { google_json_key_string: json_key })
        )
      rescue StandardError => e
        abort("\nThere might be something wrong with the JSON key file - [ERROR] #{e}")
      end

      # Path to GCS service account json key file
      # Or the content of the key file as a hash
      def json_key
        unless ENV['QA_FAILED_TEST_RESOURCES_GCS_CREDENTIALS']
          abort("\nPlease provide QA_FAILED_TEST_RESOURCES_GCS_CREDENTIALS")
        end

        @json_key ||= ENV["QA_FAILED_TEST_RESOURCES_GCS_CREDENTIALS"]
      end

      # In environments that we can run tests with admin scope,
      # we should use GITLAB_QA_ADMIN_ACCESS_TOKEN to clean up resources.
      # This is necessary for cleaning up User resources.
      def personal_access_token
        if ENV['GITLAB_QA_ADMIN_ACCESS_TOKEN'].blank? && ENV['GITLAB_QA_ACCESS_TOKEN'].blank?
          abort("\nPlease provide either GITLAB_QA_ADMIN_ACCESS_TOKEN or GITLAB_QA_ACCESS_TOKEN")
        end

        @personal_access_token ||= ENV['GITLAB_QA_ADMIN_ACCESS_TOKEN'] || ENV['GITLAB_QA_ACCESS_TOKEN']
      end
    end
  end
end
