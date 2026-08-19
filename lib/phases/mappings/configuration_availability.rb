# frozen_string_literal: true

require_relative "../../copy_comparison"

module Phases
  class Mappings
    class ConfigurationAvailability
      UNPLANNED = Object.new.freeze

      def initialize(load_mappings:)
        @load_mappings = load_mappings
        @planned_targets = UNPLANNED
      end

      def record(plan)
        @planned_targets = plan.filter_map do |operation|
          operation.target if operation.establishes_target?
        end
      end

      def reset
        @planned_targets = UNPLANNED
      end

      def targets
        return planned_targets unless planned_targets.equal?(UNPLANNED)

        load_mappings.call.filter_map { |mapping| mapping.target if current?(mapping) }
      end

      private

      attr_reader :load_mappings, :planned_targets

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
end
