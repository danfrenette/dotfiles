# frozen_string_literal: true

require_relative "cli_installation"
require_relative "fork_workspace"
require_relative "plan"

module Phases
  module OpenCode2
    class Phase
      def initialize(global_dir:, bin_dir:, checkout:, package_manager_candidates:, command_runner:, reporter:)
        @cli_installation = CLIInstallation.new(
          global_dir: global_dir,
          bin_dir: bin_dir,
          package_manager_candidates: package_manager_candidates,
          command_runner: command_runner
        )
        @fork_workspace = ForkWorkspace.new(checkout: checkout, command_runner: command_runner)
        @reporter = reporter
      end

      def plan
        reporter.report_phase("Installing OpenCode2")

        Plan.new(cli: cli_installation.plan, fork: fork_workspace.plan).tap do |plan|
          plan.items.each { |item| reporter.report_action(item.fetch(:type), item.fetch(:meta)) }
        end
      end

      def apply(plan)
        cli_installation.apply(plan.cli)
        fork_workspace.apply(plan.fork)
      end

      private

      attr_reader :cli_installation, :fork_workspace, :reporter
    end
  end
end
