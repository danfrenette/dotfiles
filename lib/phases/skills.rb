# frozen_string_literal: true

require_relative "skills/plan"
require_relative "../prepared_phase"
require_relative "../reporters/console_reporter"
require_relative "error"

module Phases
  class Skills
    NAME = :skills
    CATALOG = "danfrenette/skills"
    VERSION = "1.5.22"

    class Error < Phases::Error; end

    def initialize(package_manager_candidates:, command_runner:)
      @package_manager_candidates = package_manager_candidates
      @command_runner = command_runner
    end

    def name
      NAME
    end

    def prepare
      plan = build_plan
      PreparedPhase.new(plan) { apply(plan) }
    end

    private

    attr_reader :package_manager_candidates, :command_runner

    def build_plan
      Reporters::ConsoleReporter.current.report_phase("Installing skills")

      package_manager = command_runner.find_executable("pnpm", candidates: package_manager_candidates)
      raise Error, "pnpm not found; run dotfiles setup before refresh" unless package_manager

      Plan.new(package_manager: package_manager).tap do |plan|
        plan.report
      end
    end

    def apply(plan)
      result = command_runner.run(*plan.command)
      raise Error, "skills installation could not start" if result.nil?
      raise Error, "skills installation exited with a nonzero status" unless result
    end
  end
end
