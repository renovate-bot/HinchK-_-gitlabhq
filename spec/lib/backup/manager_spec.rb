# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Backup::Manager, feature_category: :backup_restore do
  include StubENV

  let(:progress) { StringIO.new }
  let(:backup_tasks) { nil }
  let(:options) { build(:backup_options, :skip_none) }

  subject { described_class.new(progress, backup_tasks: backup_tasks) }

  before do
    # Rspec fails with `uninitialized constant RSpec::Support::Differ` when it
    # is trying to display a diff and `File.exist?` is stubbed. Adding a
    # default stub fixes this.
    allow(File).to receive(:exist?).and_call_original
    allow(FileUtils).to receive(:rm_rf).and_call_original

    allow(progress).to receive(:puts)
    allow(progress).to receive(:print)
  end

  def backup_path
    Pathname(Gitlab.config.backup.path)
  end

  describe '#run_create_task' do
    let(:terraform_state) do
      Backup::Tasks::TerraformState.new(progress: progress, options: options)
                                   .tap { |state| allow(state).to receive(:target).and_return(target) }
    end

    let(:target) { instance_double(Backup::Targets::Target) }
    let(:backup_tasks) do
      { 'terraform_state' => terraform_state }
    end

    it 'runs the provided task' do
      expect(target).to receive(:dump)
      expect(Gitlab::BackupLogger).to receive(:info).with(message: 'Dumping terraform states ... ')
      expect(Gitlab::BackupLogger).to receive(:info).with(message: 'Dumping terraform states ... done')

      subject.run_create_task(terraform_state)
    end

    context 'when disabled' do
      it 'does not run the task and informs the user' do
        allow(terraform_state).to receive(:enabled).and_return(false)

        expect(target).not_to receive(:dump)
        expect(Gitlab::BackupLogger).to receive(:info).with(message: 'Dumping terraform states ... [DISABLED]')

        subject.run_create_task(terraform_state)
      end
    end

    context 'when skipped' do
      it 'does not run the task and informs the user' do
        stub_env('SKIP', 'terraform_state')

        expect(target).not_to receive(:dump)
        expect(Gitlab::BackupLogger).to receive(:info).with(message: 'Dumping terraform states ... [SKIPPED]')

        subject.run_create_task(terraform_state)
      end
    end
  end

  describe '#run_restore_task' do
    let(:terraform_state) do
      Backup::Tasks::TerraformState.new(progress: progress, options: options)
                                   .tap { |task| allow(task).to receive(:target).and_return(target) }
    end

    let(:pre_restore_warning) { '' }
    let(:post_restore_warning) { '' }
    let(:target) do
      instance_double(::Backup::Targets::Target,
        pre_restore_warning: pre_restore_warning,
        post_restore_warning: post_restore_warning)
    end

    let(:backup_tasks) do
      { 'terraform_state' => terraform_state }
    end

    let(:backup_information) { { backup_created_at: Time.zone.parse('2019-01-01'), gitlab_version: '12.3' } }

    before do
      allow_next_instance_of(Backup::Metadata) do |metadata|
        allow(metadata).to receive(:load_from_file).and_return(backup_information)
      end
    end

    it 'runs the provided task' do
      expect(target).to receive(:restore)
      expect(Gitlab::BackupLogger).to receive(:info).with(message: 'Restoring terraform states ... ').ordered
      expect(Gitlab::BackupLogger).to receive(:info).with(message: 'Restoring terraform states ... done').ordered

      subject.run_restore_task(terraform_state)
    end

    context 'when disabled' do
      it 'does not run the task and informs the user' do
        allow(terraform_state).to receive(:enabled).and_return(false)

        expect(target).not_to receive(:restore)
        expect(Gitlab::BackupLogger).to receive(:info).with(message: 'Restoring terraform states ... [DISABLED]').ordered

        subject.run_restore_task(terraform_state)
      end
    end

    describe 'pre_restore_warning' do
      let(:pre_restore_warning) { 'Watch out!' }

      it 'displays and waits for the user' do
        expect(Gitlab::BackupLogger).to receive(:info).with(message: 'Restoring terraform states ... ').ordered
        expect(Gitlab::BackupLogger).to receive(:info).with(message: 'Watch out!').ordered
        expect(Gitlab::BackupLogger).to receive(:info).with(message: 'Restoring terraform states ... done').ordered
        expect(Gitlab::TaskHelpers).to receive(:ask_to_continue)
        expect(target).to receive(:restore)

        subject.run_restore_task(terraform_state)
      end

      it 'does not continue when the user quits' do
        expect(Gitlab::BackupLogger).to receive(:info).with(message: 'Restoring terraform states ... ').ordered
        expect(Gitlab::BackupLogger).to receive(:info).with(message: 'Watch out!').ordered
        expect(Gitlab::BackupLogger).to receive(:info).with(message: 'Quitting...').ordered
        expect(Gitlab::TaskHelpers).to receive(:ask_to_continue).and_raise(Gitlab::TaskAbortedByUserError)

        expect do
          subject.run_restore_task(terraform_state)
        end.to raise_error(SystemExit)
      end
    end

    describe 'post_restore_warning' do
      let(:post_restore_warning) { 'Watch out!' }

      it 'displays and waits for the user' do
        expect(Gitlab::BackupLogger).to receive(:info).with(message: 'Restoring terraform states ... ').ordered
        expect(Gitlab::BackupLogger).to receive(:info).with(message: 'Restoring terraform states ... done').ordered
        expect(Gitlab::BackupLogger).to receive(:info).with(message: 'Watch out!').ordered
        expect(Gitlab::TaskHelpers).to receive(:ask_to_continue)
        expect(target).to receive(:restore)

        subject.run_restore_task(terraform_state)
      end

      it 'does not continue when the user quits' do
        expect(Gitlab::BackupLogger).to receive(:info).with(message: 'Restoring terraform states ... ').ordered
        expect(Gitlab::BackupLogger).to receive(:info).with(message: 'Restoring terraform states ... done').ordered
        expect(Gitlab::BackupLogger).to receive(:info).with(message: 'Watch out!').ordered
        expect(Gitlab::BackupLogger).to receive(:info).with(message: 'Quitting...').ordered
        expect(target).to receive(:restore)
        expect(Gitlab::TaskHelpers).to receive(:ask_to_continue).and_raise(Gitlab::TaskAbortedByUserError)

        expect do
          subject.run_restore_task(terraform_state)
        end.to raise_error(SystemExit)
      end
    end
  end

  describe '#create' do
    let(:incremental_env) { 'false' }
    let(:expected_backup_contents) { %w[backup_information.yml lfs.tar.gz pages.tar.gz] }
    let(:backup_time) { Time.zone.parse('2019-1-1') }
    let(:backup_id) { "1546300800_2019_01_01_#{Gitlab::VERSION}" }
    let(:full_backup_id) { backup_id }
    let(:pack_tar_file) { "#{backup_id}_gitlab_backup.tar" }
    let(:pack_tar_system_options) { { out: [pack_tar_file, 'w', Gitlab.config.backup.archive_permissions] } }
    let(:pack_tar_cmdline) { ['tar', '-cf', '-', *expected_backup_contents, pack_tar_system_options] }

    let(:lfs) do
      Backup::Tasks::Lfs.new(progress: progress, options: options)
                                   .tap { |task| allow(task).to receive(:target).and_return(target1) }
    end

    let(:pages) do
      Backup::Tasks::Pages.new(progress: progress, options: options)
                          .tap { |task| allow(task).to receive(:target).and_return(target2) }
    end

    let(:target1) { instance_double(Backup::Targets::Target) }
    let(:target2) { instance_double(Backup::Targets::Target) }
    let(:backup_tasks) do
      { 'lfs' => lfs, 'pages' => pages }
    end

    before do
      stub_env('INCREMENTAL', incremental_env)
      allow(ApplicationRecord.connection).to receive(:reconnect!)
      allow(Gitlab::BackupLogger).to receive(:info)
      allow(Kernel).to receive(:system).and_return(true)

      allow(target1).to receive(:dump).with(backup_path.join('lfs.tar.gz'), backup_id)
      allow(target2).to receive(:dump).with(backup_path.join('pages.tar.gz'), backup_id)
    end

    it 'creates a backup tar' do
      travel_to(backup_time) do
        subject.create # rubocop:disable Rails/SaveBang
      end

      expect(Kernel).to have_received(:system).with(*pack_tar_cmdline)
      expect(FileUtils).to have_received(:rm_rf).with(backup_path.join('backup_information.yml'))
      expect(FileUtils).to have_received(:rm_rf).with(backup_path.join('tmp'))
    end

    context 'when BACKUP is set' do
      let(:backup_id) { 'custom' }

      before do
        stub_env('BACKUP', '/ignored/path/custom')
      end

      it 'uses the given value as tar file name' do
        subject.create # rubocop:disable Rails/SaveBang

        expect(Kernel).to have_received(:system).with(*pack_tar_cmdline)
      end

      context 'tar fails' do
        before do
          expect(Kernel).to receive(:system).with(*pack_tar_cmdline).and_return(false)
        end

        it 'logs a failure' do
          expect do
            subject.create # rubocop:disable Rails/SaveBang
          end.to raise_error(Backup::Error, 'Backup failed')

          expect(Gitlab::BackupLogger).to have_received(:info).with(message: "Creating archive #{pack_tar_file} failed")
          expect(FileUtils).to have_received(:rm_rf).with(backup_path.join('backup_information.yml'))
          expect(FileUtils).to have_received(:rm_rf).with(backup_path.join('tmp'))
        end
      end

      context 'when SKIP env is set' do
        let(:expected_backup_contents) { %w[backup_information.yml lfs.tar.gz] }

        before do
          stub_env('SKIP', 'pages')
        end

        it 'executes tar' do
          subject.create # rubocop:disable Rails/SaveBang

          expect(Kernel).to have_received(:system).with(*pack_tar_cmdline)
        end
      end

      context 'when the destination is optional' do
        let(:expected_backup_contents) { %w[backup_information.yml lfs.tar.gz] }
        let(:pages) do
          Backup::Tasks::Pages.new(progress: progress, options: options)
                              .tap do |task|
            allow(task).to receive_messages(target: target2, destination_optional: true)
          end
        end

        it 'executes tar' do
          expect(File).to receive(:exist?).with(backup_path.join('pages.tar.gz')).and_return(false)

          subject.create # rubocop:disable Rails/SaveBang

          expect(Kernel).to have_received(:system).with(*pack_tar_cmdline)
        end
      end

      context 'many backup files' do
        let(:files) do
          %w[
            1451606400_2016_01_01_1.2.3_gitlab_backup.tar
            1451520000_2015_12_31_4.5.6_gitlab_backup.tar
            1451520000_2015_12_31_4.5.6-pre_gitlab_backup.tar
            1451520000_2015_12_31_4.5.6-rc1_gitlab_backup.tar
            1451520000_2015_12_31_4.5.6-pre-ee_gitlab_backup.tar
            1451510000_2015_12_30_gitlab_backup.tar
            1450742400_2015_12_22_gitlab_backup.tar
            1449878400_gitlab_backup.tar
            1449014400_gitlab_backup.tar
            manual_gitlab_backup.tar
          ]
        end

        before do
          allow(Gitlab::BackupLogger).to receive(:info)
          allow(Dir).to receive(:chdir).and_yield
          allow(Dir).to receive(:glob).and_return(files)
          allow(FileUtils).to receive(:rm)
          allow(Time).to receive(:now).and_return(Time.zone.parse('2016-1-1'))
        end

        context 'when keep_time is zero' do
          before do
            allow(Gitlab.config.backup).to receive(:keep_time).and_return(0)

            subject.create # rubocop:disable Rails/SaveBang
          end

          it 'removes no files' do
            expect(FileUtils).not_to have_received(:rm)
          end

          it 'prints a skipped message' do
            expect(Gitlab::BackupLogger).to have_received(:info).with(message: 'Deleting old backups ... [SKIPPED]')
          end
        end

        context 'when no valid file is found' do
          let(:files) do
            %w[
              14516064000_2016_01_01_1.2.3_gitlab_backup.tar
              foo_1451520000_2015_12_31_4.5.6_gitlab_backup.tar
              1451520000_2015_12_31_4.5.6-foo_gitlab_backup.tar
            ]
          end

          before do
            allow(Gitlab.config.backup).to receive(:keep_time).and_return(1)

            subject.create # rubocop:disable Rails/SaveBang
          end

          it 'removes no files' do
            expect(FileUtils).not_to have_received(:rm)
          end

          it 'prints a done message' do
            expect(Gitlab::BackupLogger).to have_received(:info).with(message: 'Deleting old backups ... done. (0 removed)')
          end
        end

        context 'when there are no files older than keep_time' do
          before do
            # Set to 30 days
            allow(Gitlab.config.backup).to receive(:keep_time).and_return(2592000)

            subject.create # rubocop:disable Rails/SaveBang
          end

          it 'removes no files' do
            expect(FileUtils).not_to have_received(:rm)
          end

          it 'prints a done message' do
            expect(Gitlab::BackupLogger).to have_received(:info).with(message: 'Deleting old backups ... done. (0 removed)')
          end
        end

        context 'when keep_time is set to remove files' do
          before do
            # Set to 1 second
            allow(Gitlab.config.backup).to receive(:keep_time).and_return(1)

            subject.create # rubocop:disable Rails/SaveBang
          end

          it 'removes matching files with a human-readable versioned timestamp' do
            expect(FileUtils).to have_received(:rm).with(files[1])
            expect(FileUtils).to have_received(:rm).with(files[2])
            expect(FileUtils).to have_received(:rm).with(files[3])
          end

          it 'removes matching files with a human-readable versioned timestamp with tagged EE' do
            expect(FileUtils).to have_received(:rm).with(files[4])
          end

          it 'removes matching files with a human-readable non-versioned timestamp' do
            expect(FileUtils).to have_received(:rm).with(files[5])
            expect(FileUtils).to have_received(:rm).with(files[6])
          end

          it 'removes matching files without a human-readable timestamp' do
            expect(FileUtils).to have_received(:rm).with(files[7])
            expect(FileUtils).to have_received(:rm).with(files[8])
          end

          it 'does not remove files that are not old enough' do
            expect(FileUtils).not_to have_received(:rm).with(files[0])
          end

          it 'does not remove non-matching files' do
            expect(FileUtils).not_to have_received(:rm).with(files[9])
          end

          it 'prints a done message' do
            expect(Gitlab::BackupLogger).to have_received(:info).with(message: 'Deleting old backups ... done. (8 removed)')
          end
        end

        context 'when removing a file fails' do
          let(:file) { files[1] }
          let(:message) { "Permission denied @ unlink_internal - #{file}" }

          before do
            allow(Gitlab.config.backup).to receive(:keep_time).and_return(1)
            allow(FileUtils).to receive(:rm).with(file).and_raise(Errno::EACCES, message)

            subject.create # rubocop:disable Rails/SaveBang
          end

          it 'removes the remaining expected files' do
            expect(FileUtils).to have_received(:rm).with(files[4])
            expect(FileUtils).to have_received(:rm).with(files[5])
            expect(FileUtils).to have_received(:rm).with(files[6])
            expect(FileUtils).to have_received(:rm).with(files[7])
            expect(FileUtils).to have_received(:rm).with(files[8])
          end

          it 'sets the correct removed count' do
            expect(Gitlab::BackupLogger).to have_received(:info).with(message: 'Deleting old backups ... done. (7 removed)')
          end

          it 'prints the error from file that could not be removed' do
            expect(Gitlab::BackupLogger).to have_received(:info).with(message: a_string_matching(message))
          end
        end
      end

      describe 'cloud storage' do
        let(:backup_file) { Tempfile.new('backup', Gitlab.config.backup.path) }
        let(:backup_filename) { File.basename(backup_file.path) }

        before do
          allow(Gitlab::BackupLogger).to receive(:info)
          allow_next_instance_of(described_class) do |manager|
            allow(manager).to receive(:tar_file).and_return(backup_filename)
            allow(manager.remote_storage).to receive(:tar_file).and_return(backup_filename)
          end

          stub_backup_setting(
            upload: {
              connection: {
                provider: 'AWS',
                aws_access_key_id: 'id',
                aws_secret_access_key: 'secret'
              },
              remote_directory: 'directory',
              multipart_chunk_size: 104857600,
              encryption: nil,
              encryption_key: nil,
              storage_class: nil
            }
          )

          Fog.mock!

          # the Fog mock only knows about directories we create explicitly
          connection = ::Fog::Storage.new(Gitlab.config.backup.upload.connection.symbolize_keys)
          connection.directories.create(key: Gitlab.config.backup.upload.remote_directory) # rubocop:disable Rails/SaveBang
        end

        context 'skipped upload' do
          let(:backup_information) do
            {
              backup_created_at: Time.zone.parse('2019-01-01'),
              gitlab_version: '12.3',
              skipped: ['remote']
            }
          end

          it 'informs the user' do
            stub_env('SKIP', 'remote')
            subject.create # rubocop:disable Rails/SaveBang

            expect(Gitlab::BackupLogger).to have_received(:info).with(message: 'Uploading backup archive to remote storage directory ... [SKIPPED]')
          end
        end

        context 'target path' do
          it 'uses the tar filename by default' do
            expect_any_instance_of(Fog::Collection).to receive(:create)
              .with(hash_including(key: backup_filename, public: false))
              .and_call_original

            subject.create # rubocop:disable Rails/SaveBang
          end

          it 'adds the DIRECTORY environment variable if present' do
            stub_env('DIRECTORY', 'daily')

            expect_any_instance_of(Fog::Collection).to receive(:create)
              .with(hash_including(key: "daily/#{backup_filename}", public: false))
              .and_call_original

            subject.create # rubocop:disable Rails/SaveBang
          end
        end

        context 'with AWS with server side encryption' do
          let(:connection) { ::Fog::Storage.new(Gitlab.config.backup.upload.connection.symbolize_keys) }
          let(:encryption_key) { nil }
          let(:encryption) { nil }
          let(:storage_options) { nil }

          before do
            stub_backup_setting(
              upload: {
                connection: {
                  provider: 'AWS',
                  aws_access_key_id: 'AWS_ACCESS_KEY_ID',
                  aws_secret_access_key: 'AWS_SECRET_ACCESS_KEY'
                },
                remote_directory: 'directory',
                multipart_chunk_size: Gitlab.config.backup.upload.multipart_chunk_size,
                encryption: encryption,
                encryption_key: encryption_key,
                storage_options: storage_options,
                storage_class: nil
              }
            )

            connection.directories.create(key: Gitlab.config.backup.upload.remote_directory) # rubocop:disable Rails/SaveBang
          end

          context 'with SSE-S3 without using storage_options' do
            let(:encryption) { 'AES256' }

            it 'sets encryption attributes' do
              subject.create # rubocop:disable Rails/SaveBang

              expect(Gitlab::BackupLogger).to have_received(:info).with(message: 'Uploading backup archive to remote storage directory ... done (encrypted with AES256)')
            end
          end

          context 'with SSE-C (customer-provided keys) options' do
            let(:encryption) { 'AES256' }
            let(:encryption_key) { SecureRandom.hex }

            it 'sets encryption attributes' do
              subject.create # rubocop:disable Rails/SaveBang

              expect(Gitlab::BackupLogger).to have_received(:info).with(message: 'Uploading backup archive to remote storage directory ... done (encrypted with AES256)')
            end
          end

          context 'with SSE-KMS options' do
            let(:storage_options) do
              {
                server_side_encryption: 'aws:kms',
                server_side_encryption_kms_key_id: 'arn:aws:kms:12345'
              }
            end

            it 'sets encryption attributes' do
              subject.create # rubocop:disable Rails/SaveBang

              expect(Gitlab::BackupLogger).to have_received(:info).with(message: 'Uploading backup archive to remote storage directory ... done (encrypted with aws:kms)')
            end
          end
        end

        context 'with Google provider' do
          before do
            stub_backup_setting(
              upload: {
                connection: {
                  provider: 'Google',
                  google_storage_access_key_id: 'test-access-id',
                  google_storage_secret_access_key: 'secret'
                },
                remote_directory: 'directory',
                multipart_chunk_size: Gitlab.config.backup.upload.multipart_chunk_size,
                encryption: nil,
                encryption_key: nil,
                storage_class: nil
              }
            )

            connection = ::Fog::Storage.new(Gitlab.config.backup.upload.connection.symbolize_keys)
            connection.directories.create(key: Gitlab.config.backup.upload.remote_directory) # rubocop:disable Rails/SaveBang
          end

          it 'does not attempt to set ACL' do
            expect_any_instance_of(Fog::Collection).to receive(:create)
              .with(hash_excluding(public: false))
              .and_call_original

            subject.create # rubocop:disable Rails/SaveBang
          end
        end

        context 'with AzureRM provider' do
          before do
            stub_backup_setting(
              upload: {
                connection: {
                  provider: 'AzureRM',
                  azure_storage_account_name: 'test-access-id',
                  azure_storage_access_key: 'secret'
                },
                remote_directory: 'directory',
                multipart_chunk_size: nil,
                encryption: nil,
                encryption_key: nil,
                storage_class: nil
              }
            )
          end

          it 'loads the provider' do
            expect { subject.create }.not_to raise_error # rubocop:disable Rails/SaveBang
          end
        end
      end
    end

    context 'tar skipped' do
      before do
        stub_env('SKIP', 'tar')
      end

      after do
        FileUtils.rm_rf(Dir.glob(backup_path.join('*')), secure: true)
      end

      it 'creates a non-tarred backup' do
        travel_to(backup_time) do
          subject.create # rubocop:disable Rails/SaveBang
        end

        expect(Kernel).not_to have_received(:system).with(*pack_tar_cmdline)
        expect(subject.send(:backup_information).to_h).to include(
          backup_id: backup_id,
          backup_created_at: backup_time.localtime,
          db_version: be_a(String),
          gitlab_version: Gitlab::VERSION,
          installation_type: Gitlab::INSTALLATION_TYPE,
          skipped: 'tar',
          tar_version: be_a(String)
        )
        expect(FileUtils).to have_received(:rm_rf).with(backup_path.join('tmp'))
      end
    end

    context 'incremental' do
      let(:incremental_env) { 'true' }
      let(:gitlab_version) { Gitlab::VERSION }
      let(:backup_id) { "1546300800_2019_01_01_#{gitlab_version}" }
      let(:unpack_tar_file) { "#{full_backup_id}_gitlab_backup.tar" }
      let(:unpack_tar_cmdline) { ['tar', '-xf', unpack_tar_file] }
      let(:backup_information) do
        {
          backup_created_at: Time.zone.parse('2018-01-01'),
          gitlab_version: gitlab_version
        }
      end

      before do
        allow_next_instance_of(Backup::Metadata) do |metadata|
          allow(metadata).to receive(:load_from_file).and_return(backup_information)
        end
      end

      context 'when there are no backup files in the directory' do
        before do
          allow(Dir).to receive(:glob).and_return([])
        end

        it 'fails the operation and prints an error' do
          expect { subject.create }.to raise_error SystemExit # rubocop:disable Rails/SaveBang
          expect(progress).to have_received(:puts)
            .with(a_string_matching('No backups found'))
        end
      end

      context 'when there are two backup files in the directory and BACKUP variable is not set' do
        before do
          allow(Dir).to receive(:glob).and_return(
            %w[
              1451606400_2016_01_01_1.2.3_gitlab_backup.tar
              1451520000_2015_12_31_gitlab_backup.tar
            ]
          )
        end

        it 'prints the list of available backups' do
          expect { subject.create }.to raise_error SystemExit # rubocop:disable Rails/SaveBang
          expect(progress).to have_received(:puts).with(a_string_matching('1451606400_2016_01_01_1.2.3'))
          expect(progress).to have_received(:puts).with(a_string_matching('1451520000_2015_12_31'))
        end

        it 'fails the operation and prints an error' do
          expect { subject.create }.to raise_error SystemExit # rubocop:disable Rails/SaveBang
          expect(progress).to have_received(:puts)
            .with(a_string_matching('Found more than one backup'))
        end
      end

      context 'when BACKUP variable is set to a non-existing file' do
        before do
          allow(Dir).to receive(:glob).and_return(
            [
              '1451606400_2016_01_01_gitlab_backup.tar'
            ]
          )
          allow(File).to receive(:exist?).and_return(false)

          stub_env('BACKUP', 'wrong')
        end

        it 'fails the operation and prints an error' do
          expect { subject.create }.to raise_error SystemExit # rubocop:disable Rails/SaveBang
          expect(File).to have_received(:exist?).with('wrong_gitlab_backup.tar')
          expect(progress).to have_received(:puts)
            .with(a_string_matching('The backup file wrong_gitlab_backup.tar does not exist'))
        end
      end

      context 'when BACKUP variable is set to a correct file' do
        let(:backup_id) { '1451606400_2016_01_01_1.2.3' }

        before do
          allow(Gitlab::BackupLogger).to receive(:info)
          allow(Dir).to receive(:glob).and_return(
            [
              '1451606400_2016_01_01_1.2.3_gitlab_backup.tar'
            ]
          )
          allow(File).to receive(:exist?).and_return(true)
          allow(Kernel).to receive(:system).and_return(true)

          stub_env('BACKUP', '/ignored/path/1451606400_2016_01_01_1.2.3')
        end

        it 'unpacks and packs the backup' do
          travel_to(backup_time) do
            subject.create # rubocop:disable Rails/SaveBang
          end

          expect(Kernel).to have_received(:system).with(*unpack_tar_cmdline)
          expect(Kernel).to have_received(:system).with(*pack_tar_cmdline)
          expect(FileUtils).to have_received(:rm_rf).with(backup_path.join('backup_information.yml'))
          expect(FileUtils).to have_received(:rm_rf).with(backup_path.join('tmp'))
        end

        context 'untar fails' do
          before do
            expect(Kernel).to receive(:system).with(*unpack_tar_cmdline).and_return(false)
          end

          it 'logs a failure' do
            expect do
              subject.create # rubocop:disable Rails/SaveBang
            end.to raise_error(SystemExit)

            expect(Gitlab::BackupLogger).to have_received(:info).with(message: 'Unpacking backup failed')
          end
        end

        context 'tar fails' do
          before do
            expect(Kernel).to receive(:system).with(*pack_tar_cmdline).and_return(false)
          end

          it 'logs a failure' do
            expect do
              subject.create # rubocop:disable Rails/SaveBang
            end.to raise_error(Backup::Error, 'Backup failed')

            expect(Gitlab::BackupLogger).to have_received(:info).with(message: "Creating archive #{pack_tar_file} failed")
            expect(FileUtils).to have_received(:rm_rf).with(backup_path.join('backup_information.yml'))
            expect(FileUtils).to have_received(:rm_rf).with(backup_path.join('tmp'))
          end
        end

        context 'on version mismatch' do
          let(:backup_information) do
            {
              backup_created_at: Time.zone.parse('2019-01-01'),
              gitlab_version: "not #{gitlab_version}"
            }
          end

          it 'stops the process' do
            expect { subject.create }.to raise_error SystemExit # rubocop:disable Rails/SaveBang
            expect(progress).to have_received(:puts)
              .with(a_string_matching('GitLab version mismatch'))
          end
        end
      end

      context 'when PREVIOUS_BACKUP variable is set to a non-existing file' do
        before do
          allow(Dir).to receive(:glob).and_return(
            [
              '1451606400_2016_01_01_gitlab_backup.tar'
            ]
          )
          allow(File).to receive(:exist?).and_return(false)

          stub_env('PREVIOUS_BACKUP', 'wrong')
        end

        it 'fails the operation and prints an error' do
          expect { subject.create }.to raise_error SystemExit # rubocop:disable Rails/SaveBang
          expect(File).to have_received(:exist?).with('wrong_gitlab_backup.tar')
          expect(progress).to have_received(:puts)
            .with(a_string_matching('The backup file wrong_gitlab_backup.tar does not exist'))
        end
      end

      context 'when PREVIOUS_BACKUP variable is set to a correct file' do
        let(:full_backup_id) { 'some_previous_backup' }

        before do
          allow(Gitlab::BackupLogger).to receive(:info)
          allow(Dir).to receive(:glob).and_return(
            [
              'some_previous_backup_gitlab_backup.tar'
            ]
          )
          allow(File).to receive(:exist?).with('some_previous_backup_gitlab_backup.tar').and_return(true)
          allow(Kernel).to receive(:system).and_return(true)

          stub_env('PREVIOUS_BACKUP', '/ignored/path/some_previous_backup')
        end

        it 'unpacks and packs the backup' do
          travel_to(backup_time) do
            subject.create # rubocop:disable Rails/SaveBang
          end

          expect(Kernel).to have_received(:system).with(*unpack_tar_cmdline)
          expect(Kernel).to have_received(:system).with(*pack_tar_cmdline)
          expect(FileUtils).to have_received(:rm_rf).with(backup_path.join('backup_information.yml'))
          expect(FileUtils).to have_received(:rm_rf).with(backup_path.join('tmp'))
        end

        context 'untar fails' do
          before do
            expect(Kernel).to receive(:system).with(*unpack_tar_cmdline).and_return(false)
          end

          it 'logs a failure' do
            expect do
              travel_to(backup_time) do
                subject.create # rubocop:disable Rails/SaveBang
              end
            end.to raise_error(SystemExit)

            expect(Gitlab::BackupLogger).to have_received(:info).with(message: 'Unpacking backup failed')
          end
        end

        context 'tar fails' do
          before do
            expect(Kernel).to receive(:system).with(*pack_tar_cmdline).and_return(false)
          end

          it 'logs a failure' do
            expect do
              travel_to(backup_time) do
                subject.create # rubocop:disable Rails/SaveBang
              end
            end.to raise_error(Backup::Error, 'Backup failed')

            expect(Gitlab::BackupLogger).to have_received(:info).with(message: "Creating archive #{pack_tar_file} failed")
            expect(FileUtils).to have_received(:rm_rf).with(backup_path.join('backup_information.yml'))
            expect(FileUtils).to have_received(:rm_rf).with(backup_path.join('tmp'))
          end
        end

        context 'on version mismatch' do
          let(:backup_information) do
            {
              backup_created_at: Time.zone.parse('2018-01-01'),
              gitlab_version: "not #{gitlab_version}"
            }
          end

          it 'stops the process' do
            expect { subject.create }.to raise_error SystemExit # rubocop:disable Rails/SaveBang
            expect(progress).to have_received(:puts)
              .with(a_string_matching('GitLab version mismatch'))
          end
        end
      end

      context 'when there is a non-tarred backup in the directory' do
        let(:full_backup_id) { "1514764800_2018_01_01_#{Gitlab::VERSION}" }
        let(:backup_information) do
          {
            backup_created_at: Time.zone.parse('2018-01-01'),
            gitlab_version: gitlab_version,
            skipped: 'tar'
          }
        end

        before do
          allow(Dir).to receive(:glob).and_return(
            [
              'backup_information.yml'
            ]
          )
          allow(File).to receive(:exist?).with(backup_path.join('backup_information.yml')).and_return(true)
          stub_env('SKIP', 'pages')
        end

        after do
          FileUtils.rm(backup_path.join('backup_information.yml'), force: true)
        end

        it 'updates the non-tarred backup' do
          travel_to(backup_time) do
            subject.create # rubocop:disable Rails/SaveBang
          end

          expect(progress).to have_received(:puts)
            .with(a_string_matching('Non tarred backup found '))
          expect(progress).to have_received(:puts)
            .with(a_string_matching("Backup #{backup_id} is done"))
          expect(subject.send(:backup_information).to_h).to include(
            backup_created_at: backup_time,
            full_backup_id: full_backup_id,
            gitlab_version: Gitlab::VERSION,
            skipped: 'tar,pages')
        end

        context 'on version mismatch' do
          let(:backup_information) do
            {
              backup_created_at: Time.zone.parse('2019-01-01'),
              gitlab_version: "not #{gitlab_version}"
            }
          end

          it 'stops the process' do
            expect { subject.create }.to raise_error SystemExit # rubocop:disable Rails/SaveBang
            expect(progress).to have_received(:puts)
              .with(a_string_matching('GitLab version mismatch'))
          end
        end
      end
    end
  end

  describe '#restore' do
    let(:lfs) do
      Backup::Tasks::Lfs.new(progress: progress, options: options)
                        .tap { |task| allow(task).to receive(:target).and_return(target1) }
    end

    let(:pages) do
      Backup::Tasks::Pages.new(progress: progress, options: options)
                          .tap { |task| allow(task).to receive(:target).and_return(target2) }
    end

    let(:target1) { instance_double(Backup::Targets::Target, pre_restore_warning: nil, post_restore_warning: nil) }
    let(:target2) { instance_double(Backup::Targets::Target, pre_restore_warning: nil, post_restore_warning: nil) }
    let(:backup_tasks) do
      { 'lfs' => lfs, 'pages' => pages }
    end

    let(:gitlab_version) { Gitlab::VERSION }
    let(:backup_id) { "1546300800_2019_01_01_#{gitlab_version}" }

    let(:backup_information) do
      {
        backup_created_at: Time.zone.parse('2019-01-01'),
        gitlab_version: gitlab_version
      }
    end

    before do
      Rake.application.rake_require 'tasks/gitlab/shell'
      Rake.application.rake_require 'tasks/cache'

      allow(Gitlab::BackupLogger).to receive(:info)
      allow(target1).to receive(:restore).with(backup_path.join('lfs.tar.gz'), backup_id)
      allow(target2).to receive(:restore).with(backup_path.join('pages.tar.gz'), backup_id)
      allow_next_instance_of(Backup::Metadata) do |metadata|
        allow(metadata).to receive(:load_from_file).and_return(backup_information)
      end
      allow(Rake::Task['gitlab:shell:setup']).to receive(:invoke)
      allow(Rake::Task['cache:clear']).to receive(:invoke)
    end

    context 'when there are no backup files in the directory' do
      before do
        allow(Dir).to receive(:glob).and_return([])
      end

      it 'fails the operation and prints an error' do
        expect { subject.restore }.to raise_error SystemExit
        expect(progress).to have_received(:puts)
          .with(a_string_matching('No backups found'))
      end
    end

    context 'when there are two backup files in the directory and BACKUP variable is not set' do
      before do
        allow(Dir).to receive(:glob).and_return(
          %w[
            1451606400_2016_01_01_1.2.3_gitlab_backup.tar
            1451520000_2015_12_31_gitlab_backup.tar
          ]
        )
      end

      it 'prints the list of available backups' do
        expect { subject.restore }.to raise_error SystemExit
        expect(progress).to have_received(:puts).with(a_string_matching('1451606400_2016_01_01_1.2.3'))
        expect(progress).to have_received(:puts).with(a_string_matching('1451520000_2015_12_31'))
      end

      it 'fails the operation and prints an error' do
        expect { subject.restore }.to raise_error SystemExit
        expect(progress).to have_received(:puts)
          .with(a_string_matching('Found more than one backup'))
      end
    end

    context 'when BACKUP variable is set to a non-existing file' do
      before do
        allow(Dir).to receive(:glob).and_return(
          [
            '1451606400_2016_01_01_gitlab_backup.tar'
          ]
        )
        allow(File).to receive(:exist?).and_return(false)

        stub_env('BACKUP', 'wrong')
      end

      it 'fails the operation and prints an error' do
        expect { subject.restore }.to raise_error SystemExit
        expect(File).to have_received(:exist?).with('wrong_gitlab_backup.tar')
        expect(progress).to have_received(:puts)
          .with(a_string_matching('The backup file wrong_gitlab_backup.tar does not exist'))
      end
    end

    context 'when BACKUP variable is set to a correct file' do
      let(:tar_cmdline) { %w[tar -xf 1451606400_2016_01_01_1.2.3_gitlab_backup.tar] }
      let(:backup_id) { "1451606400_2016_01_01_1.2.3" }

      before do
        allow(Gitlab::BackupLogger).to receive(:info)
        allow(Dir).to receive(:glob).and_return(
          [
            '1451606400_2016_01_01_1.2.3_gitlab_backup.tar'
          ]
        )
        allow(File).to receive(:exist?).and_return(true)
        allow(Kernel).to receive(:system).and_return(true)

        stub_env('BACKUP', '/ignored/path/1451606400_2016_01_01_1.2.3')
      end

      it 'unpacks the file' do
        subject.restore

        expect(Kernel).to have_received(:system).with(*tar_cmdline)
        expect(FileUtils).to have_received(:rm_rf).with(backup_path.join('backup_information.yml'))
        expect(FileUtils).to have_received(:rm_rf).with(backup_path.join('tmp'))
      end

      context 'backup information mismatches' do
        let(:backup_id) { 'pineapple' }
        let(:backup_information) do
          {
            backup_id: backup_id,
            backup_created_at: Time.zone.parse('2019-01-01'),
            gitlab_version: gitlab_version
          }
        end

        it 'unpacks the BACKUP specified file but uses the backup information backup ID' do
          expect(target1).to receive(:restore).with(backup_path.join('lfs.tar.gz'), backup_id)
          expect(target2).to receive(:restore).with(backup_path.join('pages.tar.gz'), backup_id)

          subject.restore

          expect(Kernel).to have_received(:system).with(*tar_cmdline)
          expect(FileUtils).to have_received(:rm_rf).with(backup_path.join('backup_information.yml'))
          expect(FileUtils).to have_received(:rm_rf).with(backup_path.join('tmp'))
        end
      end

      context 'tar fails' do
        before do
          expect(Kernel).to receive(:system).with(*tar_cmdline).and_return(false)
        end

        it 'logs a failure' do
          expect do
            subject.restore
          end.to raise_error(SystemExit)

          expect(Gitlab::BackupLogger).to have_received(:info).with(message: 'Unpacking backup failed')
        end
      end

      context 'on version mismatch' do
        let(:backup_information) do
          {
            backup_created_at: Time.zone.parse('2019-01-01'),
            gitlab_version: "not #{gitlab_version}"
          }
        end

        it 'stops the process' do
          expect { subject.restore }.to raise_error SystemExit
          expect(progress).to have_received(:puts)
            .with(a_string_matching('GitLab version mismatch'))
        end
      end
    end

    context 'when there is a non-tarred backup in the directory' do
      before do
        allow(Dir).to receive(:glob).and_return(
          [
            'backup_information.yml'
          ]
        )
        allow(File).to receive(:exist?).and_return(true)
      end

      it 'selects the non-tarred backup to restore from' do
        expect(Kernel).not_to receive(:system)

        subject.restore

        expect(progress).to have_received(:puts)
          .with(a_string_matching('Non tarred backup found '))
        expect(FileUtils).to have_received(:rm_rf).with(backup_path.join('tmp'))
      end

      context 'on version mismatch' do
        let(:backup_information) do
          {
            backup_created_at: Time.zone.parse('2019-01-01'),
            gitlab_version: "not #{gitlab_version}"
          }
        end

        it 'stops the process' do
          expect { subject.restore }.to raise_error SystemExit
          expect(progress).to have_received(:puts)
            .with(a_string_matching('GitLab version mismatch'))
        end
      end
    end
  end
end
