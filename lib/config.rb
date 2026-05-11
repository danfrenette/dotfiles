# frozen_string_literal: true

require "yaml"

class Config
  DOTFILES_ROOT = File.expand_path("..", __dir__).freeze
  MAPPINGS_PATH = File.join(DOTFILES_ROOT, "config", "mappings.yml").freeze

  def mappings
    mappings_data.flat_map do |category, files|
      files.map do |source, target|
        [dotfiles_path(source), expand_home(target)]
      end
    end.to_h
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

  def skills_source_root
    dotfiles_path("skills")
  end

  def opencode_skills_target
    home_path(".config", "opencode", "skill")
  end

  def skills_manifest_path
    dotfiles_path("skills.yml")
  end

  def skills_lock_path
    dotfiles_path("skills.lock")
  end

  def skills_cache_dir
    home_path(".cache", "dotfiles-skills")
  end

  private

  def mappings_data
    @mappings_data ||= YAML.safe_load_file(MAPPINGS_PATH) || {}
  end

  def expand_home(path)
    return path unless path.start_with?("~")

    File.join(Dir.home, path[1..])
  end
end
