# frozen_string_literal: true

module Phases
  class Neovim
    class Plan
      attr_reader :executable,
        :curl,
        :plugin_manager_path,
        :plugin_manager_url,
        :configuration_targets

      def initialize(executable:, curl:, plugin_manager_path:, plugin_manager_url:, configuration_targets:)
        @executable = executable
        @curl = curl
        @plugin_manager_path = plugin_manager_path
        @plugin_manager_url = plugin_manager_url
        @configuration_targets = configuration_targets.dup.freeze
        freeze
      end

      def command
        [executable, "--headless", "+PlugInstall", "+qa"]
      end

      def plugin_manager_command
        [curl, "-fLo", plugin_manager_path, plugin_manager_url]
      end

      def items
        items = []
        unless File.file?(plugin_manager_path)
          items << {
            type: :install,
            meta: {command: plugin_manager_command}
          }
        end
        items << {
          type: :neovim,
          meta: {executable: executable, configuration_targets: configuration_targets, command: command}
        }
        items
      end
    end
  end
end
