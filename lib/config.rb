# frozen_string_literal: true

class Config
  DOTFILES_ROOT = File.expand_path("..", __dir__)

  def mappings
    {}.merge(git_mappings).merge(zsh_mappings).merge(nvim_mappings).merge(opencode_mappings)
  end

  def dotfiles_path(*parts)
    File.join(DOTFILES_ROOT, *parts)
  end

  def home_path(*parts)
    File.join(Dir.home, *parts)
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
        "reviewer.md") => home_path(".config", "opencode", "agent", "reviewer.md"),
      dotfiles_path("config", "opencode", "agent",
        "technical-writer.md") => home_path(".config", "opencode", "agent", "technical-writer.md")
    }
  end
end
