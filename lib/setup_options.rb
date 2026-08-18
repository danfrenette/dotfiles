# frozen_string_literal: true

class SetupOptions
  SUPPORTED_PHASES = [:homebrew, :opencode2, :mappings, :skills, :neovim].freeze
  DEFAULTS = {
    skip_brew: false,
    dry_run: false,
    yes: false,
    only: []
  }.freeze

  attr_reader :skip_brew,
    :dry_run,
    :yes,
    :only

  def initialize(**values)
    validate_keys(values)
    options = DEFAULTS.merge(values)
    selected = Array(options.fetch(:only))
    validate_phases(selected)

    @skip_brew = options.fetch(:skip_brew)
    @dry_run = options.fetch(:dry_run)
    @yes = options.fetch(:yes)
    @only = selected.uniq.freeze

    freeze
  end

  private

  def validate_keys(values)
    unknown = values.keys - DEFAULTS.keys
    return if unknown.empty?

    raise ArgumentError, "Unknown setup options: #{unknown.join(", ")}"
  end

  def validate_phases(phases)
    unsupported = phases - SUPPORTED_PHASES
    return if unsupported.empty?

    raise ArgumentError, "Unsupported phase: #{unsupported.first}"
  end
end
