# frozen_string_literal: true

require_relative "skills/plan"
require_relative "skills/catalog"
require_relative "../prepared_phase"
require_relative "../reporters/console_reporter"
require_relative "error"

module Phases
  class Skills
    NAME = :skills
    CATALOG_PATH = File.expand_path("../../config/skills.yml", __dir__)
    VERSION = "1.5.23"

    class Error < Phases::Error; end

    def initialize(package_manager_candidates:, command_runner:, catalog_path: nil)
      @package_manager_candidates = package_manager_candidates
      @command_runner = command_runner
      @catalog_path = catalog_path || CATALOG_PATH
    end

    def name
      NAME
    end

    def prepare
      plan = build_plan
      PreparedPhase.new(plan) { apply(plan) }
    end

    private

    attr_reader :package_manager_candidates, :command_runner, :catalog_path

    def build_plan
      Reporters::ConsoleReporter.current.report_phase("Installing skills")

      package_manager = command_runner.find_executable("pnpm", candidates: package_manager_candidates)
      raise Error, "pnpm not found; run dotfiles setup before refresh" unless package_manager

      catalogs = Catalog.load(catalog_path)
      Plan.new(package_manager: package_manager, catalogs: catalogs).tap do |plan|
        plan.report
      end
    end

    def apply(plan)
      plan.commands.each do |command|
        result = command_runner.run(*command)
        raise Error, "skills installation could not start" if result.nil?
        raise Error, "skills installation exited with a nonzero status" unless result
      end
    end
  end
end
