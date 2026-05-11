# frozen_string_literal: true

require_relative "linker"
require_relative "config"
require_relative "skill_installer"
require_relative "reporters/console_reporter"

class Installer
  def initialize(skip_brew: false, dry_run: false, update_skills: false, skills_only: false, linker: nil, config: Config.new, skill_installer: nil, reporter: nil)
    @skip_brew = skip_brew
    @dry_run = dry_run
    @update_skills = update_skills
    @skills_only = skills_only
    @config = config
    @linker = linker || Linker.new(dry_run: dry_run)
    @reporter = reporter || Reporters::ConsoleReporter.new
    @skill_installer = skill_installer || SkillInstaller.new(dry_run: dry_run, update_skills: update_skills, config: config, reporter: @reporter)
  end

  def install
    return install_skills if skills_only

    install_brew_packages unless skip_brew
    link_dotfiles
    post_install
  end

  private

  attr_reader :skip_brew, :dry_run, :update_skills, :skills_only, :linker, :config, :skill_installer, :reporter

  def install_skills
    reporter.report_phase("Installing skills")
    skill_installer.install
  end

  def install_brew_packages
    reporter.report_phase("Installing Homebrew packages")

    unless File.exist?(config.brewfile_path)
      reporter.report_warning("Brewfile not found, skipping")
      return
    end

    if dry_run
      reporter.report_action(:skipped, message: "brew bundle --file=#{config.brewfile_path}")
      return
    end

    success = system("brew bundle --file=#{config.brewfile_path}")
    reporter.report_warning("brew bundle failed, continuing anyway") unless success
  end

  def link_dotfiles
    reporter.report_phase("Linking dotfiles")

    config.mappings.each do |source, target|
      result = linker.link(source, target)
      reporter.report_action(result, source: source, target: target)
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

    if dry_run
      reporter.report_action(:skipped, message: "would run nvim --headless +PlugInstall +qa")
      return
    end

    system('nvim --headless "+PlugInstall" "+qa" 2>/dev/null')
  end

  def report_completion
    if dry_run
      reporter.report_dry_completion
    else
      reporter.report_completion([
        "Restart your terminal (or run: exec zsh)",
        "Open nvim and run :PlugInstall if plugins weren't installed"
      ])
    end
  end
end
