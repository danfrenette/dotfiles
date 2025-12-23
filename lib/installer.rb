# frozen_string_literal: true

require_relative "linker"
require_relative "config"

# Orchestrates the full dotfiles installation
class Installer
  def initialize(output: $stdout, skip_brew: false)
    @output = output
    @skip_brew = skip_brew
    @linker = Linker.new
    @config = Config.new
  end

  def install
    install_brew_packages unless @skip_brew
    link_dotfiles
    post_install
  end

  def install_brew_packages
    header "Installing Homebrew packages"

    brewfile = File.join(Config::DOTFILES_ROOT, "Brewfile")
    unless File.exist?(brewfile)
      warn "Brewfile not found, skipping"
      return
    end

    system("brew bundle --file=#{brewfile}")
  end

  def link_dotfiles
    header "Linking dotfiles"

    @config.mappings.each do |source, target|
      result = @linker.link(source, target)
      log_link_result(source, target, result)
    end
  end

  def post_install
    header "Post-install"

    # Install vim-plug plugins
    if File.exist?(File.expand_path("~/.config/nvim/init.lua"))
      log "Installing Neovim plugins..."
      system('nvim --headless "+PlugInstall" "+qa" 2>/dev/null')
      log "  done"
    end

    log ""
    log "Installation complete!"
    log ""
    log "Next steps:"
    log "  1. Restart your terminal (or run: exec zsh)"
    log "  2. Open nvim and run :PlugInstall if plugins weren't installed"
  end

  private

  def header(text)
    log ""
    log "=== #{text} ==="
    log ""
  end

  def log(message)
    @output.puts message
  end

  def warn(message)
    @output.puts "  [SKIP] #{message}"
  end

  def log_link_result(source, target, result)
    filename = source.sub("#{Config::DOTFILES_ROOT}/", "")
    case result
    when :linked
      log "  [LINK] #{filename} -> #{target}"
    when :already_linked
      log "  [OK]   #{filename}"
    end
  end
end
