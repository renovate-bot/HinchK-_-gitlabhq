# frozen_string_literal: true

module Backup
  module Tasks
    class Registry < Task
      def self.id = 'registry'

      def enabled = Gitlab.config.registry.enabled

      def human_name = _('container registry images')

      def destination_path = 'registry.tar.gz'

      def target
        ::Backup::Targets::Files.new(progress, storage_path, options: options)
      end

      private

      def storage_path
        Settings.registry.path
      end
    end
  end
end
