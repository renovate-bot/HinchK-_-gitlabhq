# frozen_string_literal: true

module Backup
  module Tasks
    class Builds < Task
      def self.id = 'builds'

      def human_name = _('builds')

      def destination_path = 'builds.tar.gz'

      def target
        ::Backup::Targets::Files.new(progress, storage_path, options: options)
      end

      private

      def storage_path
        Settings.gitlab_ci.builds_path
      end
    end
  end
end
