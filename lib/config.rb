# frozen_string_literal: true

require "yaml"
require_relative "mapping_manifest"

class Config
  DOTFILES_ROOT = File.expand_path("..", __dir__).freeze
  MAPPINGS_PATH = File.join(DOTFILES_ROOT, "config", "mappings.yml").freeze

  def initialize(repository_root: DOTFILES_ROOT, home_root: Dir.home, mappings_path: nil)
    @repository_root = File.expand_path(repository_root)
    @home_root = File.expand_path(home_root)
    @mappings_path = mappings_path ? File.expand_path(mappings_path) : File.join(@repository_root, "config", "mappings.yml")
  end

  def mappings
    @mappings ||= MappingManifest.load(
      @mappings_path,
      repository_root: @repository_root,
      home_root: @home_root
    )
  end

  def dotfiles_path(*parts)
    File.join(@repository_root, *parts)
  end

  def home_path(*parts)
    File.join(@home_root, *parts)
  end

  def nvim_init_target
    home_path(".config", "nvim", "init.lua")
  end

  def brewfile_path
    dotfiles_path("Brewfile")
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

  def local_skills
    Array(skills_data["local_skills"])
  end

  private

  def skills_data
    @skills_data ||= YAML.safe_load_file(skills_manifest_path) || {}
  end
end
