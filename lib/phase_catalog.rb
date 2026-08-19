# frozen_string_literal: true

require_relative "continuing_phase"
require_relative "phases/homebrew"
require_relative "phases/mappings"
require_relative "phases/neovim"
require_relative "phases/opencode2"
require_relative "phases/skills"

class PhaseCatalog
  include Enumerable

  class UnsupportedPhase < StandardError; end

  def self.build(config:, runtime:)
    load_mappings = config.method(:mappings)
    availability = Phases::Mappings::ConfigurationAvailability.new(load_mappings: load_mappings)

    new([
      homebrew(config, runtime),
      continuing_opencode2(config, runtime),
      mappings(load_mappings, availability, runtime),
      skills(config, runtime),
      neovim(config, availability, runtime)
    ], reset_planning: availability.method(:reset))
  end

  def initialize(phases, reset_planning: -> {})
    @phases = phases.dup.freeze
    @reset_planning = reset_planning
    validate_unique_names
  end

  def each(&block)
    phases.each(&block)
  end

  def names
    phases.map(&:name)
  end

  def phases_for(names)
    unsupported = names - self.names
    raise UnsupportedPhase, "Unsupported phase: #{unsupported.first}" unless unsupported.empty?

    phases.select { |phase| names.include?(phase.name) }
  end

  def prepare(selected)
    reset_planning.call
    selected.map(&:prepare)
  end

  private

  attr_reader :phases, :reset_planning

  def validate_unique_names
    duplicate = names.find { |name| names.count(name) > 1 }
    raise ArgumentError, "Duplicate catalog phase: #{duplicate}" if duplicate
  end

  class << self
    private

    def homebrew(config, runtime)
      Phases::Homebrew.new(
        brewfile_path: config.brewfile_path,
        command_runner: runtime.command_runner,
        reporter: runtime.reporter
      )
    end

    def continuing_opencode2(config, runtime)
      ContinuingPhase.new(
        phase: opencode2(config, runtime),
        reporter: runtime.reporter,
        planning_errors: [Phases::OpenCode2::Error, SystemCallError],
        application_errors: [Phases::OpenCode2::Error]
      )
    end

    def opencode2(config, runtime)
      Phases::OpenCode2::Phase.new(
        global_dir: config.opencode2_global_dir,
        bin_dir: config.user_bin_dir,
        checkout: config.opencode_fork_checkout,
        package_manager_candidates: config.pnpm_candidates,
        command_runner: runtime.command_runner,
        reporter: runtime.reporter
      )
    end

    def mappings(load_mappings, availability, runtime)
      Phases::Mappings.new(
        load_mappings: load_mappings,
        availability: availability,
        reporter: runtime.reporter
      )
    end

    def skills(config, runtime)
      Phases::Skills.new(
        package_manager_candidates: config.pnpm_candidates,
        command_runner: runtime.command_runner,
        reporter: runtime.reporter
      )
    end

    def neovim(config, availability, runtime)
      Phases::Neovim.new(
        load_configuration_targets: config.method(:nvim_configuration_targets),
        availability: availability,
        command_runner: runtime.command_runner,
        reporter: runtime.reporter
      )
    end
  end
end
