# frozen_string_literal: true

require_relative "neovim/plan"
require_relative "../prepared_phase"
require_relative "error"

module Phases
  class Neovim
    NAME = :neovim

    class Error < Phases::Error; end

    def initialize(load_configuration_targets:, availability:, command_runner:, reporter:)
      @load_configuration_targets = load_configuration_targets
      @availability = availability
      @command_runner = command_runner
      @reporter = reporter
    end

    def name
      NAME
    end

    def prepare
      plan = build_plan
      PreparedPhase.new(plan) { apply(plan) }
    end

    private

    attr_reader :load_configuration_targets, :availability, :command_runner, :reporter

    def build_plan
      reporter.report_phase("Installing Neovim plugins")

      executable = command_runner.find_executable("nvim")
      raise Error, "Neovim not found; install nvim before running this phase" unless executable

      missing_targets = configuration_targets - availability.targets
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

      reporter.report_action(:neovim_complete, command: plan.command)
    end

    def configuration_targets
      @configuration_targets ||= load_configuration_targets.call
    end
  end
end
