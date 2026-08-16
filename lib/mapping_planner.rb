# frozen_string_literal: true

require_relative "mapping_change"

class MappingPlanner
  def initialize(backup_suffix:)
    @backup_suffix = backup_suffix
  end

  def plan(mappings)
    mappings.flat_map do |mapping|
      MappingChange.new(mapping, backup_suffix: backup_suffix).operations
    end
  end

  private

  attr_reader :backup_suffix
end
