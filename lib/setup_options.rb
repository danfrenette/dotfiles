# frozen_string_literal: true

class SetupOptions
  DEFAULTS = {
    workflow: nil,
    dry_run: false,
    yes: false
  }.freeze

  attr_reader :workflow,
    :dry_run,
    :yes

  def initialize(**values)
    validate_keys(values)
    options = DEFAULTS.merge(values)

    @workflow = options.fetch(:workflow)
    @dry_run = options.fetch(:dry_run)
    @yes = options.fetch(:yes)

    freeze
  end

  private

  def validate_keys(values)
    unknown = values.keys - DEFAULTS.keys
    return if unknown.empty?

    raise ArgumentError, "Unknown setup options: #{unknown.join(", ")}"
  end
end
