# frozen_string_literal: true

require_relative "../mapping_change"
require_relative "../mapping_plan_applier"
require_relative "../prepared_phase"
require_relative "../reporters/console_reporter"
require_relative "mappings/configuration_availability"

module Phases
  class Mappings
    NAME = :mappings

    def initialize(load_mappings:, availability:, plan_applier: MappingPlanApplier.new)
      @load_mappings = load_mappings
      @availability = availability
      @plan_applier = plan_applier
    end

    def name
      NAME
    end

    def prepare
      plan = build_plan
      availability.record(plan)
      PreparedPhase.new(plan) { plan_applier.apply(plan) }
    end

    private

    attr_reader :load_mappings, :availability, :plan_applier

    def build_plan
      reporter = Reporters::ConsoleReporter.current
      reporter.report_phase("Linking dotfiles")

      loaded_mappings.flat_map { |mapping| MappingChange.new(mapping).operations }.tap do |operations|
        operations.each { |operation| reporter.report_action(operation.type, operation.meta) }
      end
    end

    def loaded_mappings
      load_mappings.call
    end
  end
end
