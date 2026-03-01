# frozen_string_literal: true

# Defines mappings between dotfiles sources and their target locations
class Config
  DOTFILES_ROOT = File.expand_path("..", __dir__).freeze
  MAPPING_METHODS = %i[
    git_mappings zsh_mappings nvim_mappings opencode_mappings ghostty_mappings tmux_mappings ruby_mappings
    psql_mappings cursor_mappings
  ].freeze

  def mappings
    MAPPING_METHODS.map { |m| send(m) }.reduce({}, :merge)
  end

  def dotfiles_path(*parts)
    File.join(DOTFILES_ROOT, *parts)
  end

  def home_path(*parts)
    File.join(Dir.home, *parts)
  end

  def nvim_init_target
    home_path(".config", "nvim", "init.lua")
  end

  def brewfile_path
    File.join(DOTFILES_ROOT, "Brewfile")
  end

  private

  def git_mappings
    {
      dotfiles_path("git", "gitconfig") => home_path(".gitconfig"),
      dotfiles_path("git", "gitignore") => home_path(".gitignore"),
      dotfiles_path("git", "gitmessage") => home_path(".gitmessage"),
      dotfiles_path("git", "ignore") => home_path(".config", "git", "ignore")
    }
  end

  def zsh_mappings
    {
      dotfiles_path("zsh", "zshrc") => home_path(".zshrc"),
      dotfiles_path("zsh", "zprofile") => home_path(".zprofile")
    }
  end

  def nvim_mappings
    {
      dotfiles_path("config", "nvim", "init.lua") => home_path(".config", "nvim", "init.lua"),
      dotfiles_path("config", "nvim", "lua", "options.lua") => home_path(".config", "nvim", "lua", "options.lua"),
      dotfiles_path("config", "nvim", "lua", "keymaps.lua") => home_path(".config", "nvim", "lua", "keymaps.lua"),
      dotfiles_path("config", "nvim", "lua", "plugins.lua") => home_path(".config", "nvim", "lua", "plugins.lua"),
      dotfiles_path("config", "nvim", "lua", "autocmds.lua") => home_path(".config", "nvim", "lua", "autocmds.lua")
    }
  end

  def opencode_mappings
    {
      dotfiles_path("config", "opencode", "agent",
        "build-confirm.md") => home_path(".config", "opencode", "agent", "build-confirm.md"),
      dotfiles_path("config", "opencode", "agent",
        "commit-writer.md") => home_path(".config", "opencode", "agent", "commit-writer.md"),
      dotfiles_path("config", "opencode", "agent",
        "prd-writer.md") => home_path(".config", "opencode", "agent", "prd-writer.md"),
      dotfiles_path("config", "opencode", "agent",
        "reviewer.md") => home_path(".config", "opencode", "agent", "reviewer.md"),
      dotfiles_path("config", "opencode", "agent",
        "ticket-writer.md") => home_path(".config", "opencode", "agent", "ticket-writer.md")
    }
  end

  def ghostty_mappings
    {
      dotfiles_path("config", "ghostty", "config") => home_path(".config", "ghostty", "config")
    }
  end

  def tmux_mappings
    {
      dotfiles_path("tmux", "tmux.conf") => home_path(".tmux.conf")
    }
  end

  def ruby_mappings
    {
      dotfiles_path("ruby", "irbrc") => home_path(".irbrc"),
      dotfiles_path("ruby", "pryrc") => home_path(".pryrc")
    }
  end

  def psql_mappings
    {
      dotfiles_path("config", "psqlrc") => home_path(".psqlrc")
    }
  end

  def cursor_mappings
    {
      dotfiles_path("cursor", "commands") => home_path(".cursor", "commands")
    }
  end
end
