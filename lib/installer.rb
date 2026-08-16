# frozen_string_literal: true

require_relative "linker"
require_relative "config"
require_relative "skill_installer"
require_relative "setup_options"
require_relative "setup_runtime"

class Installer
  def initialize(options: SetupOptions.new, config: Config.new, runtime: SetupRuntime.new)
    @options = options
    @config = config
    @runtime = runtime
    @linker = Linker.new(dry_run: options.dry_run)
  end

  def install
    return install_skills_only if options.skills_only

    plan = plan_mappings
    return complete_dry_run if options.dry_run
    return 0 unless confirmed?(plan)

    apply_setup(plan)
  rescue ArgumentError, SystemCallError => error
    report_failure(error)
  end

  private

  attr_reader :options, :config, :runtime, :linker

  def reporter
    runtime.reporter
  end

  def install_skills_only
    install_skills
    0
  end

  def complete_dry_run
    reporter.report_dry_completion
    0
  end

  def confirmed?(plan)
    plan.empty? || options.yes || runtime.prompt.confirm?
  end

  def apply_setup(plan)
    install_brew_packages unless options.skip_brew || options.only == :mappings
    linker.apply(plan)
    return 0 if options.only == :mappings

    post_install
    0
  end

  def report_failure(error)
    reporter.report_warning(error.message)
    1
  end

  def install_skills
    guard_against_recursive_skills_destination

    reporter.report_phase("Installing skills")
    skills = local_skills

    if skills.empty?
      reporter.report_warning("no skills found in #{config.skills_source_root}")
      return
    end

    skill_installer = SkillInstaller.new(dry_run: options.dry_run, linker: linker, reporter: reporter)
    skill_installer.install(skills, target_dir: config.opencode_skills_target)
  end

  def local_skills
    config.local_skills.to_h do |path|
      source = File.join(config.skills_source_root, path)
      [File.basename(path), source]
    end
  end

  def guard_against_recursive_skills_destination
    return unless File.symlink?(config.opencode_skills_target)

    destination = File.realpath(config.opencode_skills_target)
    source_root = File.realpath(config.skills_source_root)
    return unless destination == source_root || destination.start_with?("#{source_root}/")

    raise "#{config.opencode_skills_target} is a symlink into this repo (#{destination})"
  rescue Errno::ENOENT
    nil
  end

  def install_brew_packages
    reporter.report_phase("Installing Homebrew packages")

    unless File.exist?(config.brewfile_path)
      reporter.report_warning("Brewfile not found, skipping")
      return
    end

    if options.dry_run
      reporter.report_action(:skipped, message: "brew bundle --file=#{config.brewfile_path}")
      return
    end

    success = runtime.command_runner.call("brew", "bundle", "--file=#{config.brewfile_path}")
    reporter.report_warning("brew bundle failed, continuing anyway") unless success
  end

  def plan_mappings
    reporter.report_phase("Linking dotfiles")

    linker.plan(config.mappings).tap do |plan|
      plan.each do |operation|
        reporter.report_action(operation.fetch(:type), operation.except(:type))
      end
    end
  end

  def post_install
    install_skills

    reporter.report_phase("Post-install")
    install_nvim_plugins
    report_completion
  end

  def install_nvim_plugins
    return unless File.exist?(config.nvim_init_target)

    if options.dry_run
      reporter.report_action(:skipped, message: "would run nvim --headless +PlugInstall +qa")
      return
    end

    runtime.command_runner.call("nvim", "--headless", "+PlugInstall", "+qa", err: File::NULL)
  end

  def report_completion
    if options.dry_run
      reporter.report_dry_completion
    else
      reporter.report_completion([
        "Restart your terminal (or run: exec zsh)",
        "Open nvim and run :PlugInstall if plugins weren't installed"
      ])
    end
  end
end
