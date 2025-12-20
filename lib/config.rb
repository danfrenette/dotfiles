# frozen_string_literal: true

class Config
  DOTFILES_ROOT = File.expand_path("..", __dir__)

  def mappings
    {}
  end

  def dotfiles_path(*parts)
    File.join(DOTFILES_ROOT, *parts)
  end

  def home_path(*parts)
    File.join(Dir.home, *parts)
  end
end
