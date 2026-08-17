# frozen_string_literal: true

require_relative "neovim/plan"

module Phases
  class Neovim
    class Error < StandardError; end

    def initialize(configuration_targets:, command_runner:, reporter:)
      @configuration_targets = configuration_targets
      @command_runner = command_runner
      @reporter = reporter
    end

    def plan(available_targets:)
      reporter.report_phase("Installing Neovim plugins")

      executable = command_runner.find_executable("nvim")
      raise Error, "Neovim not found; install nvim before running this phase" unless executable

      missing_targets = configuration_targets - available_targets
      unless missing_targets.empty?
        raise Error, "Neovim configuration is not available: #{missing_targets.join(", ")}"
      end

      Plan.new(executable: executable, configuration_targets: configuration_targets).tap do |plan|
        plan.items.each { |item| reporter.report_action(item.fetch(:type), item.fetch(:meta)) }
      end
    end

    def apply(plan)
      result = command_runner.run(*plan.command)
      raise Error, "Neovim plugin installation could not start" if result.nil?
      raise Error, "Neovim plugin installation exited with a nonzero status" unless result
    end

    private

    attr_reader :configuration_targets, :command_runner, :reporter
  end
end
