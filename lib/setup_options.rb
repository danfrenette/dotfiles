# frozen_string_literal: true

class SetupOptions
  SUPPORTED_PHASES = [:homebrew, :mappings, :opencode2].freeze
  DEFAULTS = {
    skip_brew: false,
    dry_run: false,
    skills_only: false,
    yes: false,
    only: nil
  }.freeze

  attr_reader :skip_brew,
    :dry_run,
    :skills_only,
    :yes,
    :only

  def initialize(**values)
    validate_keys(values)
    options = DEFAULTS.merge(values)
    validate_phase(options.fetch(:only))
    validate_phase_selection(options)

    @skip_brew = options.fetch(:skip_brew)
    @dry_run = options.fetch(:dry_run)
    @skills_only = options.fetch(:skills_only)
    @yes = options.fetch(:yes)
    @only = options.fetch(:only)

    freeze
  end

  private

  def validate_keys(values)
    unknown = values.keys - DEFAULTS.keys
    return if unknown.empty?

    raise ArgumentError, "Unknown setup options: #{unknown.join(", ")}"
  end

  def validate_phase(phase)
    return if phase.nil? || SUPPORTED_PHASES.include?(phase)

    raise ArgumentError, "Unsupported phase: #{phase}"
  end

  def validate_phase_selection(options)
    return unless options.fetch(:only) && options.fetch(:skills_only)

    raise ArgumentError, "--only and --skills-only cannot be combined"
  end
end
