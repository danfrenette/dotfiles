# frozen_string_literal: true

require_relative "phases/homebrew"
require_relative "phases/mappings"
require_relative "phases/neovim"
require_relative "phases/opencode2"
require_relative "phases/skills"
require_relative "workflow"

class PhaseCatalog
  PHASE_DESCRIPTIONS = {
    homebrew: "Install baseline packages from Brewfile",
    opencode2: "Install OpenCode2 and prepare its development workspace",
    mappings: "Link dotfiles into the home directory",
    skills: "Install agent skills",
    neovim: "Install Neovim plugins"
  }.freeze

  REFRESH_PHASES = %i[mappings skills].freeze
  SETUP_PHASES = [:homebrew, :opencode2, *REFRESH_PHASES, :neovim].freeze

  WORKFLOWS = {
    setup: {
      phases: SETUP_PHASES,
      preflight: %i[homebrew mappings]
    },
    refresh: {
      phases: REFRESH_PHASES,
      preflight: REFRESH_PHASES
    }
  }.freeze

  class UnsupportedWorkflow < StandardError; end

  def self.build(config:, runtime:, workflows: WORKFLOWS)
    new(config: config, runtime: runtime, workflows: workflows).build
  end

  def initialize(phases = nil, config: nil, runtime: nil, reporter: nil, workflows: WORKFLOWS, reset_planning: -> {})
    @config = config
    @runtime = runtime
    @workflows = workflows.freeze
    initialize_catalog(phases, reporter: reporter, reset_planning: reset_planning) if phases
  end

  def build
    raise ArgumentError, "config and runtime are required to build a catalog" unless config && runtime

    @load_mappings = config.method(:mappings)
    @availability = Phases::Mappings::ConfigurationAvailability.new(load_mappings: load_mappings)
    initialize_catalog(
      [homebrew, opencode2, mappings, skills, neovim],
      reporter: runtime.reporter,
      reset_planning: availability.method(:reset)
    )
    self
  end

  def names
    phases.map(&:name)
  end

  def workflow(name)
    definition = workflows[name]
    raise UnsupportedWorkflow, "Unsupported workflow: #{name}" unless definition

    reset_planning.call
    Workflow.new(
      name: name,
      phases: definition.fetch(:phases).map { |phase_name| phase_named(phase_name) },
      preflight: definition.fetch(:preflight),
      descriptions: PHASE_DESCRIPTIONS,
      reporter: reporter
    )
  end

  private

  attr_reader :config,
    :runtime,
    :phases,
    :reporter,
    :workflows,
    :reset_planning,
    :load_mappings,
    :availability

  def initialize_catalog(phases, reporter:, reset_planning:)
    @phases = phases.dup.freeze
    @reporter = reporter
    @reset_planning = reset_planning
    validate_unique_names
    validate_workflows
  end

  def phase_named(name)
    phases.find { |phase| phase.name == name } || raise(ArgumentError, "Workflow references missing phase: #{name}")
  end

  def validate_unique_names
    duplicate = names.find { |name| names.count(name) > 1 }
    raise ArgumentError, "Duplicate catalog phase: #{duplicate}" if duplicate
  end

  def validate_workflows
    workflows.each_value do |definition|
      definition.fetch(:phases).each { |name| phase_named(name) }
    end
  end

  def homebrew
    Phases::Homebrew.new(
      brewfile_path: config.brewfile_path,
      command_runner: runtime.command_runner,
      reporter: runtime.reporter
    )
  end

  def opencode2
    Phases::OpenCode2::Phase.new(
      global_dir: config.opencode2_global_dir,
      bin_dir: config.user_bin_dir,
      checkout: config.opencode_fork_checkout,
      package_manager_candidates: config.pnpm_candidates,
      command_runner: runtime.command_runner,
      reporter: runtime.reporter
    )
  end

  def mappings
    Phases::Mappings.new(
      load_mappings: load_mappings,
      availability: availability,
      reporter: runtime.reporter
    )
  end

  def skills
    Phases::Skills.new(
      package_manager_candidates: config.pnpm_candidates,
      command_runner: runtime.command_runner,
      reporter: runtime.reporter
    )
  end

  def neovim
    Phases::Neovim.new(
      load_configuration_targets: config.method(:nvim_configuration_targets),
      plugin_manager_path: config.nvim_plugin_manager_path,
      availability: availability,
      command_runner: runtime.command_runner,
      reporter: runtime.reporter
    )
  end
end
