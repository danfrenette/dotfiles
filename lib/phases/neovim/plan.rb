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

      def report_to(reporter)
        reporter.report_planned(:run, plugin_manager_command.join(" ")) unless File.file?(plugin_manager_path)
        reporter.report_planned(
          :nvim,
          "#{command.join(" ")} (configuration: #{configuration_targets.join(", ")})"
        )
      end
    end
  end
end
