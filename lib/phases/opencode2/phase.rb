# frozen_string_literal: true

require_relative "cli_installation"
require_relative "fork_workspace"
require_relative "plan"
require_relative "../../prepared_phase"
require_relative "../../reporters/console_reporter"

module Phases
  module OpenCode2
    class Phase
      NAME = :opencode2

      def initialize(global_dir:, bin_dir:, checkout:, package_manager_candidates:, command_runner:)
        @cli_installation = CLIInstallation.new(
          global_dir: global_dir,
          bin_dir: bin_dir,
          package_manager_candidates: package_manager_candidates,
          command_runner: command_runner
        )
        @fork_workspace = ForkWorkspace.new(checkout: checkout, command_runner: command_runner)
      end

      def name
        NAME
      end

      def prepare
        plan = build_plan
        PreparedPhase.new(plan) { apply(plan) }
      end

      private

      attr_reader :cli_installation, :fork_workspace

      def build_plan
        Reporters::ConsoleReporter.current.report_phase("Installing OpenCode2")

        Plan.new(cli: cli_installation.plan, fork: fork_workspace.plan).tap do |plan|
          plan.report
        end
      end

      def apply(plan)
        cli_installation.apply(plan.cli)
        fork_workspace.apply(plan.fork)
      end
    end
  end
end
