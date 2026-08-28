# frozen_string_literal: true

require_relative "../../reporters/console_reporter"

module Phases
  class Skills
    class Plan
      attr_reader :package_manager

      def initialize(package_manager:)
        @package_manager = package_manager
        freeze
      end

      def command
        [
          package_manager, "dlx", "skills@#{VERSION}", "add", CATALOG, "--global",
          "--agent", "opencode", "--agent", "cursor"
        ]
      end

      def report
        reporter = Reporters::ConsoleReporter.current
        reporter.report_planned(
          :skills,
          "#{command.join(" ")} (opens the skills CLI to select global OpenCode and Cursor skills)"
        )
      end
    end
  end
end
