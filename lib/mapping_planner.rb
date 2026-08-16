# frozen_string_literal: true

require_relative "mapping_change"

class MappingPlanner
  def plan(mappings)
    mappings.flat_map do |mapping|
      MappingChange.new(mapping).operations
    end
  end
end
