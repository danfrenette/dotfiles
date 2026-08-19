# frozen_string_literal: true

require_relative "../copy_comparison"
require_relative "../mapping_change"
require_relative "../mapping_plan_applier"

module Phases
  class Mappings
    def initialize(load_mappings:, reporter:, plan_applier: MappingPlanApplier.new)
      @load_mappings = load_mappings
      @reporter = reporter
      @plan_applier = plan_applier
    end

    def plan
      reporter.report_phase("Linking dotfiles")

      loaded_mappings.flat_map { |mapping| MappingChange.new(mapping).operations }.tap do |operations|
        operations.each { |operation| reporter.report_action(operation.type, operation.meta) }
      end
    end

    def apply(plan)
      plan_applier.apply(plan)
    end

    def current_targets
      loaded_mappings.filter_map { |mapping| mapping.target if current?(mapping) }
    end

    def established_targets(plan)
      plan.filter_map { |operation| operation.target if operation.establishes_target? }
    end

    private

    attr_reader :load_mappings, :reporter, :plan_applier

    def loaded_mappings
      load_mappings.call
    end

    def current?(mapping)
      return correctly_linked?(mapping.target, mapping.source) if mapping.link?

      CopyComparison.new(mapping.source, mapping.target).match?
    end

    def correctly_linked?(target, source)
      File.symlink?(target) && File.realpath(target) == File.realpath(source)
    rescue Errno::ENOENT, Errno::ELOOP, Errno::ENOTDIR
      false
    end
  end
end
