# frozen_string_literal: true

require_relative "linker"
require_relative "config"
require_relative "phases/homebrew"
require_relative "phases/neovim"
require_relative "phases/opencode2"
require_relative "phases/skills"
require_relative "setup_options"
require_relative "setup_runtime"

class Installer
  def initialize(options: SetupOptions.new, config: Config.new, runtime: SetupRuntime.new)
    @options = options
    @config = config
    @runtime = runtime
    @linker = Linker.new(dry_run: options.dry_run)
    @homebrew = Phases::Homebrew.new(
      brewfile_path: config.brewfile_path,
      command_runner: runtime.command_runner,
      reporter: runtime.reporter
    )
    @opencode2 = Phases::OpenCode2::Phase.new(
      global_dir: config.opencode2_global_dir,
      bin_dir: config.user_bin_dir,
      checkout: config.opencode_fork_checkout,
      package_manager_candidates: config.pnpm_candidates,
      command_runner: runtime.command_runner,
      reporter: runtime.reporter
    )
  end

  def install
    selected = selected_phases
    unless options.only.any?
      (SetupOptions::SUPPORTED_PHASES - selected).each do |phase|
        reporter.report_action(:skipped, message: "#{phase} phase not selected")
      end
    end
    return 0 if selected.empty?
    return install_homebrew if selected == [:homebrew]
    return install_mappings if selected == [:mappings]
    return install_neovim if selected == [:neovim]
    return install_opencode2 if selected == [:opencode2]
    return install_skills_phase if selected == [:skills]

    install_full_setup(selected)
  rescue ArgumentError, Phases::Homebrew::Error, Phases::Neovim::Error, Phases::OpenCode2::Error, Phases::Skills::Error, SystemCallError => error
    report_failure(error)
  end

  private

  attr_reader :options, :config, :runtime, :linker, :homebrew, :opencode2

  def reporter
    runtime.reporter
  end

  def neovim
    @neovim ||= Phases::Neovim.new(
      configuration_targets: config.nvim_configuration_targets,
      command_runner: runtime.command_runner,
      reporter: reporter
    )
  end

  def skills
    @skills ||= Phases::Skills.new(
      package_manager_candidates: config.pnpm_candidates,
      command_runner: runtime.command_runner,
      reporter: reporter
    )
  end

  def install_mappings
    plan = plan_mappings
    return complete_dry_run if options.dry_run
    return 0 unless confirmed?(plan)

    linker.apply(plan)
    0
  end

  def install_homebrew
    plan = homebrew.plan
    return complete_dry_run if options.dry_run
    return 0 unless options.yes || runtime.prompt.confirm?

    homebrew.apply(plan)
    reporter.report_completion
    0
  end

  def install_opencode2
    plan = opencode2.plan
    return complete_dry_run if options.dry_run
    return 0 unless options.yes || runtime.prompt.confirm?

    opencode2.apply(plan)
    reporter.report_completion
    0
  end

  def install_neovim
    plan = neovim.plan(available_targets: current_nvim_configuration_targets)
    return complete_dry_run if options.dry_run
    return 0 unless options.yes || runtime.prompt.confirm?

    neovim.apply(plan)
    reporter.report_completion
    0
  end

  def install_skills_phase
    plan = skills.plan
    return complete_dry_run if options.dry_run
    return 0 unless options.yes || runtime.prompt.confirm?

    skills.apply(plan)
    reporter.report_completion
    0
  end

  def install_full_setup(selected)
    homebrew_plan = homebrew.plan if selected.include?(:homebrew)
    opencode2_plan = if selected.include?(:opencode2)
      begin
        opencode2.plan
      rescue Phases::OpenCode2::Error, SystemCallError => error
        reporter.report_warning(error.message)
        nil
      end
    end
    mapping_plan = plan_mappings if selected.include?(:mappings)
    neovim_plan = neovim.plan(available_targets: neovim_targets(mapping_plan, selected)) if selected.include?(:neovim)
    skills_plan = skills.plan if selected.include?(:skills)
    opencode2_failed = selected.include?(:opencode2) && opencode2_plan.nil?

    return 0 unless options.dry_run || options.yes || runtime.prompt.confirm?

    unless options.dry_run
      homebrew.apply(homebrew_plan) if homebrew_plan
      if opencode2_plan
        begin
          opencode2.apply(opencode2_plan)
        rescue Phases::OpenCode2::Error => error
          reporter.report_warning(error.message)
          opencode2_failed = true
        end
      end
      linker.apply(mapping_plan) if mapping_plan
    end

    post_install(skills_plan, neovim_plan)
    opencode2_failed ? 1 : 0
  end

  def complete_dry_run
    reporter.report_dry_completion
    0
  end

  def confirmed?(plan)
    plan.empty? || options.yes || runtime.prompt.confirm?
  end

  def selected_phases
    return options.only if options.only.any?
    return SetupOptions::SUPPORTED_PHASES if options.yes

    runtime.prompt.select(SetupOptions::SUPPORTED_PHASES)
  end

  def report_failure(error)
    reporter.report_warning(error.message)
    1
  end

  def plan_mappings
    reporter.report_phase("Linking dotfiles")

    linker.plan(config.mappings).tap do |plan|
      plan.each do |operation|
        reporter.report_action(operation.type, operation.meta)
      end
    end
  end

  def post_install(skills_plan, neovim_plan)
    skills.apply(skills_plan) unless options.dry_run

    neovim.apply(neovim_plan) unless options.dry_run
    report_completion
  end

  def neovim_targets(mapping_plan, selected)
    return current_nvim_configuration_targets unless selected.include?(:mappings)

    planned_nvim_configuration_targets(mapping_plan)
  end

  def current_nvim_configuration_targets
    config.nvim_configuration_targets & linker.current_mapping_targets(config.mappings)
  end

  def planned_nvim_configuration_targets(mapping_plan)
    config.nvim_configuration_targets & linker.established_mapping_targets(mapping_plan)
  end

  def report_completion
    if options.dry_run
      reporter.report_dry_completion
    else
      reporter.report_completion([
        "Restart your terminal (or run: exec zsh)"
      ])
    end
  end
end
