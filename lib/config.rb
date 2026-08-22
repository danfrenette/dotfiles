# frozen_string_literal: true

require_relative "mapping_manifest"

class Config
  DOTFILES_ROOT = File.expand_path("..", __dir__).freeze

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

  def nvim_configuration_targets
    source_root = dotfiles_path("config", "nvim")
    mappings.filter_map { |mapping| mapping.target if mapping.source.start_with?("#{source_root}/") }
  end

  def nvim_plugin_manager_path
    home_path(".local", "share", "nvim", "site", "autoload", "plug.vim")
  end

  def brewfile_path
    dotfiles_path("Brewfile")
  end

  def opencode2_global_dir
    home_path(".local", "share", "pnpm", "global")
  end

  def user_bin_dir
    home_path(".local", "bin")
  end

  def opencode_fork_checkout
    home_path("code", "opencode")
  end

  def pnpm_candidates
    [
      "/opt/homebrew/bin/pnpm",
      "/usr/local/bin/pnpm",
      home_path("Library", "pnpm", "pnpm"),
      home_path(".local", "share", "pnpm", "pnpm")
    ]
  end
end
