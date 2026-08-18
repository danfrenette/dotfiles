# frozen_string_literal: true

class SetupOptions
  SUPPORTED_PHASES = [:homebrew, :mappings, :neovim, :opencode2, :skills].freeze
  DEFAULTS = {
    skip_brew: false,
    dry_run: false,
    yes: false,
    only: nil
  }.freeze

  attr_reader :skip_brew,
    :dry_run,
    :yes,
    :only

  def initialize(**values)
    validate_keys(values)
    options = DEFAULTS.merge(values)
    validate_phase(options.fetch(:only))

    @skip_brew = options.fetch(:skip_brew)
    @dry_run = options.fetch(:dry_run)
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
end
