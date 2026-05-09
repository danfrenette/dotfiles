# frozen_string_literal: true

require_relative "linker"
require_relative "config"
require_relative "skill_installer"

# Orchestrates the full dotfiles installation
class Installer
  def initialize(output: $stdout, skip_brew: false, dry_run: false, linker: nil, config: Config.new, skill_installer: nil)
    @output = output
    @skip_brew = skip_brew
    @dry_run = dry_run
    @config = config
    @linker = linker || Linker.new(dry_run: dry_run)
    @skill_installer = skill_installer || SkillInstaller.new(output: output, dry_run: dry_run, config: config)
  end

  def install
    install_brew_packages unless skip_brew
    link_dotfiles
    post_install
  end

  private

  attr_reader :output, :skip_brew, :dry_run, :linker, :config, :skill_installer

  def install_brew_packages
    header "Installing Homebrew packages"

    unless File.exist?(config.brewfile_path)
      warn "Brewfile not found, skipping"
      return
    end

    if dry_run
      log "  [DRY]  brew bundle --file=#{config.brewfile_path}"
      return
    end

    success = system("brew bundle --file=#{config.brewfile_path}")
    warn "brew bundle failed, continuing anyway" unless success
  end

  def link_dotfiles
    header "Linking dotfiles"

    config.mappings.each do |source, target|
      result = linker.link(source, target)
      log_link_result(source, target, result)
    end
  end

  def post_install
    header "Installing skills"
    skill_installer.install

    header "Post-install"
    install_nvim_plugins
    log_completion_message
  end

  def header(text)
    log ""
    log "=== #{text} ==="
    log ""
  end

  def log(message)
    output.puts message
  end

  def warn(message)
    output.puts "  [SKIP] #{message}"
  end

  def log_link_result(source, target, result)
    filename = source.sub("#{Config::DOTFILES_ROOT}/", "")

    case result
    when :linked
      log "  [LINK] #{filename} -> #{target}"
    when :already_linked
      log "  [OK]   #{filename}"
    when :would_link
      log "  [DRY]  #{filename} would link to #{target}"
    when :would_replace
      log "  [DRY]  #{filename} would back up #{target} -> #{target}.backup"
      log "  [DRY]  #{filename} would replace #{target}"
    else
      log "  [???]  #{filename} (unknown result: #{result})"
    end
  end

  def install_nvim_plugins
    return unless File.exist?(config.nvim_init_target)

    if dry_run
      log "[DRY]  would run nvim --headless +PlugInstall +qa"
      return
    end

    log "Installing Neovim plugins..."
    system('nvim --headless "+PlugInstall" "+qa" 2>/dev/null')
    log "  done"
  end

  def log_completion_message
    log ""
    log dry_run ? "Dry run complete!" : "Installation complete!"
    log ""
    log "Next steps:"
    log "  1. Restart your terminal (or run: exec zsh)"
    log "  2. Open nvim and run :PlugInstall if plugins weren't installed"
  end
end
