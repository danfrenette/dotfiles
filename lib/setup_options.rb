# frozen_string_literal: true

class SetupOptions
  DEFAULTS = {
    dry_run: false,
    yes: false,
    only: []
  }.freeze

  attr_reader :dry_run,
    :yes,
    :only

  def initialize(**values)
    validate_keys(values)
    options = DEFAULTS.merge(values)
    selected = Array(options.fetch(:only))
    validate_unique_phases(selected)

    @dry_run = options.fetch(:dry_run)
    @yes = options.fetch(:yes)
    @only = selected.freeze

    freeze
  end

  private

  def validate_keys(values)
    unknown = values.keys - DEFAULTS.keys
    return if unknown.empty?

    raise ArgumentError, "Unknown setup options: #{unknown.join(", ")}"
  end

  def validate_unique_phases(phases)
    duplicate = phases.find { |phase| phases.count(phase) > 1 }
    raise ArgumentError, "Duplicate phase: #{duplicate}" if duplicate
  end
end
