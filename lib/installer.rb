# frozen_string_literal: true

require_relative "config"
require_relative "phases/homebrew"
require_relative "phases/mappings"
require_relative "phases/neovim"
require_relative "phases/opencode2"
require_relative "phases/skills"
require_relative "setup_options"
require_relative "setup_runtime"

class Installer
  def self.build(options: SetupOptions.new, config: Config.new, runtime: SetupRuntime.new)
    new(
      options: options,
      prompt: runtime.prompt,
      reporter: runtime.reporter,
      homebrew: Phases::Homebrew.new(
        brewfile_path: config.brewfile_path,
        command_runner: runtime.command_runner,
        reporter: runtime.reporter
      ),
      opencode2: Phases::OpenCode2::Phase.new(
        global_dir: config.opencode2_global_dir,
        bin_dir: config.user_bin_dir,
        checkout: config.opencode_fork_checkout,
        package_manager_candidates: config.pnpm_candidates,
        command_runner: runtime.command_runner,
        reporter: runtime.reporter
      ),
      mappings: Phases::Mappings.new(
        load_mappings: config.method(:mappings),
        reporter: runtime.reporter
      ),
      skills: Phases::Skills.new(
        package_manager_candidates: config.pnpm_candidates,
        command_runner: runtime.command_runner,
        reporter: runtime.reporter
      ),
      neovim: Phases::Neovim.new(
        load_configuration_targets: config.method(:nvim_configuration_targets),
        command_runner: runtime.command_runner,
        reporter: runtime.reporter
      )
    )
  end

  def initialize(options:, prompt:, reporter:, homebrew:, opencode2:, mappings:, skills:, neovim:)
    @options = options
    @prompt = prompt
    @reporter = reporter
    @homebrew = homebrew
    @opencode2 = opencode2
    @mappings = mappings
    @skills = skills
    @neovim = neovim
  end

  def install
    selected = selected_phases
    report_skipped_phases(selected)
    return 0 if selected.empty?

    plans, opencode2_failed = plan(selected)
    return finish_dry_run(opencode2_failed) if options.dry_run
    return 0 unless options.yes || prompt.confirm?

    apply_failed = apply(plans)
    opencode2_failed ||= apply_failed
    reporter.report_completion(["Restart your terminal (or run: exec zsh)"])
    opencode2_failed ? 1 : 0
  rescue ArgumentError, Phases::Homebrew::Error, Phases::Neovim::Error, Phases::OpenCode2::Error, Phases::Skills::Error, SystemCallError => error
    reporter.report_warning(error.message)
    1
  end

  private

  attr_reader :options, :prompt, :reporter, :homebrew, :opencode2, :mappings, :skills, :neovim

  def selected_phases
    return options.only if options.only.any?
    return SetupOptions::SUPPORTED_PHASES if options.yes

    prompt.select(SetupOptions::SUPPORTED_PHASES)
  end

  def report_skipped_phases(selected)
    return if options.only.any?

    (SetupOptions::SUPPORTED_PHASES - selected).each do |phase|
      reporter.report_action(:skipped, message: "#{phase} phase not selected")
    end
  end

  def plan(selected)
    plans = {}
    plans[:homebrew] = homebrew.plan if selected.include?(:homebrew)
    opencode2_failed = plan_opencode2(plans, selected)
    plans[:mappings] = mappings.plan if selected.include?(:mappings)
    plans[:skills] = skills.plan if selected.include?(:skills)
    if selected.include?(:neovim)
      plans[:neovim] = neovim.plan(available_targets: neovim_targets(plans[:mappings], selected))
    end
    [plans, opencode2_failed]
  end

  def plan_opencode2(plans, selected)
    return false unless selected.include?(:opencode2)

    plans[:opencode2] = opencode2.plan
    false
  rescue Phases::OpenCode2::Error, SystemCallError => error
    reporter.report_warning(error.message)
    true
  end

  def apply(plans)
    homebrew.apply(plans.fetch(:homebrew)) if plans.key?(:homebrew)
    opencode2_failed = apply_opencode2(plans)
    mappings.apply(plans.fetch(:mappings)) if plans.key?(:mappings)
    skills.apply(plans.fetch(:skills)) if plans.key?(:skills)
    neovim.apply(plans.fetch(:neovim)) if plans.key?(:neovim)
    opencode2_failed
  end

  def apply_opencode2(plans)
    return false unless plans.key?(:opencode2)

    opencode2.apply(plans.fetch(:opencode2))
    false
  rescue Phases::OpenCode2::Error => error
    reporter.report_warning(error.message)
    true
  end

  def neovim_targets(mapping_plan, selected)
    return mappings.current_targets unless selected.include?(:mappings)

    mappings.established_targets(mapping_plan)
  end

  def finish_dry_run(opencode2_failed)
    reporter.report_dry_completion
    opencode2_failed ? 1 : 0
  end
end
