# frozen_string_literal: true

require_relative "linker"
require_relative "config"
require_relative "skill_installer"
require_relative "remote_skills/sources"
require_relative "reporters/console_reporter"

class Installer
  def initialize(skip_brew: false, dry_run: false, update_skills: false, skills_only: false, linker: nil, config: Config.new, reporter: nil)
    @skip_brew = skip_brew
    @dry_run = dry_run
    @update_skills = update_skills
    @skills_only = skills_only
    @config = config
    @linker = linker || Linker.new(dry_run: dry_run)
    @reporter = reporter || Reporters::ConsoleReporter.new
  end

  def install
    return install_skills if skills_only

    install_brew_packages unless skip_brew
    link_dotfiles
    post_install
  end

  private

  attr_reader :skip_brew, :dry_run, :update_skills, :skills_only, :linker, :config, :reporter

  def install_skills
    guard_against_recursive_skills_destination

    reporter.report_phase("Installing skills")
    skills = local_skills.merge(remote_skills)

    if skills.empty?
      reporter.report_warning("no skills found in #{config.skills_source_root}")
      return
    end

    skill_installer = SkillInstaller.new(dry_run: dry_run, linker: linker, reporter: reporter)
    skill_installer.install(skills, target_dir: config.opencode_skills_target)
  end

  def local_skills
    config.local_skills.to_h do |path|
      source = File.join(config.skills_source_root, path)
      [File.basename(path), source]
    end
  end

  def remote_skills
    remote_sources = RemoteSkills::Sources.new(config: config)
    remote_sources.sources(update: update_skills)
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
