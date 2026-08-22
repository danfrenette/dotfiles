# frozen_string_literal: true

require_relative "../../reporters/console_reporter"

module Phases
  module OpenCode2
    class Plan
      attr_reader :cli, :fork

      def initialize(cli:, fork:)
        @cli = cli
        @fork = fork
        freeze
      end

      def report
        reporter = Reporters::ConsoleReporter.current
        cli.report
        reporter.report_planned(
          :service,
          "#{cli.service_command.join(" ")} (start the installed service that owns shared session data)"
        )
        fork.report
        reporter.report_planned(
          :ready,
          "#{fork.launch_command.join(" ")} (proxy to the installed opencode2 service and shared sessions)"
        )
      end
    end
  end
end
