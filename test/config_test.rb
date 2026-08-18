# frozen_string_literal: true

require "test_helper"

class ConfigTest < DotfilesTestCase
  def setup
    super
    @config = Config.new
  end

  def test_mappings_returns_ordered_values
    assert_instance_of MappingManifest, @config.mappings
    assert_instance_of MappingManifest::Mapping, @config.mappings.first
  end

  def test_mappings_includes_git_configs
    mappings = @config.mappings

    assert mappings.any? { |mapping| mapping.source == @config.dotfiles_path("git", "gitconfig") }
    assert mappings.any? { |mapping| mapping.source == @config.dotfiles_path("git", "gitignore") }
    assert mappings.any? { |mapping| mapping.source == @config.dotfiles_path("git", "gitmessage") }
    assert mappings.any? { |mapping| mapping.source == @config.dotfiles_path("git", "ignore") }
  end

  def test_git_mappings_point_to_correct_targets
    mappings = @config.mappings

    gitconfig = mappings.find { |mapping| mapping.source == @config.dotfiles_path("git", "gitconfig") }
    assert_equal :link, gitconfig.operation
    assert_equal @config.home_path(".gitconfig"), gitconfig.target
  end

  def test_mappings_includes_zsh_configs
    mappings = @config.mappings

    assert mappings.any? { |mapping| mapping.source == @config.dotfiles_path("zsh", "zshrc") }
    assert mappings.any? { |mapping| mapping.source == @config.dotfiles_path("zsh", "zprofile") }
  end

  def test_zsh_mappings_point_to_correct_targets
    mappings = @config.mappings

    zsh = mappings.select { |mapping| mapping.source.include?("/zsh/") }
    assert_equal [@config.home_path(".zshrc"), @config.home_path(".zprofile")], zsh.map(&:target)
  end

  def test_mappings_includes_nvim_configs
    mappings = @config.mappings

    assert_equal 5, mappings.count { |mapping| mapping.source.include?("/config/nvim/") }
  end

  def test_nvim_mappings_point_to_correct_targets
    mappings = @config.mappings

    init = mappings.find { |mapping| mapping.source.end_with?("config/nvim/init.lua") }
    assert_equal @config.home_path(".config", "nvim", "init.lua"), init.target
  end

  def test_nvim_configuration_targets_include_all_required_modules
    assert_equal [
      @config.home_path(".config", "nvim", "init.lua"),
      @config.home_path(".config", "nvim", "lua", "options.lua"),
      @config.home_path(".config", "nvim", "lua", "keymaps.lua"),
      @config.home_path(".config", "nvim", "lua", "plugins.lua"),
      @config.home_path(".config", "nvim", "lua", "autocmds.lua")
    ], @config.nvim_configuration_targets
  end

  def test_nvim_configuration_targets_are_derived_from_the_mapping_manifest
    repository_root = create_dir("repository")
    home_root = create_dir("home")
    create_file("repository/config/nvim/init.lua")
    manifest_path = create_file("nvim-mappings.yml", <<~YAML)
      mappings:
        - operation: copy
          source: config/nvim/init.lua
          target: .config/nvim/custom.lua
    YAML
    config = Config.new(
      repository_root: repository_root,
      home_root: home_root,
      mappings_path: manifest_path
    )

    assert_equal [File.join(home_root, ".config/nvim/custom.lua")], config.nvim_configuration_targets
  end

  def test_mappings_include_ghostty_config
    mappings = @config.mappings

    assert mappings.any? { |mapping| mapping.source == @config.dotfiles_path("config", "ghostty", "config") }
  end

  def test_ghostty_mapping_points_to_correct_target
    mappings = @config.mappings

    mapping = mappings.find { |entry| entry.source.end_with?("config/ghostty/config") }
    assert_equal @config.home_path(".config", "ghostty", "config"), mapping.target
  end

  def test_all_mapping_sources_are_absolute_paths
    @config.mappings.each do |mapping|
      assert mapping.source.start_with?("/"), "Source path should be absolute: #{mapping.source}"
    end
  end

  def test_all_mapping_targets_are_absolute_paths
    @config.mappings.each do |mapping|
      assert mapping.target.start_with?("/"), "Target path should be absolute: #{mapping.target}"
    end
  end

  def test_all_real_mappings_explicitly_link
    assert @config.mappings.all?(&:link?)
  end

  def test_resolves_injected_manifest_in_order
    repository_root = create_dir("repository")
    home_root = create_dir("home")
    create_file("repository/first")
    create_file("repository/second")
    manifest_path = create_file("mappings.yml", <<~YAML)
      mappings:
        - operation: copy
          source: first
          target: .first
        - operation: link
          source: second
          target: nested/second
    YAML

    mappings = Config.new(
      repository_root: repository_root,
      home_root: home_root,
      mappings_path: manifest_path
    ).mappings

    assert_equal [:copy, :link], mappings.map(&:operation)
    assert_equal [File.join(repository_root, "first"), File.join(repository_root, "second")], mappings.map(&:source)
    assert_equal [File.join(home_root, ".first"), File.join(home_root, "nested/second")], mappings.map(&:target)
  end

  def test_dotfiles_path_returns_absolute_path
    path = @config.dotfiles_path("git", "gitconfig")

    assert path.start_with?("/")
    assert path.end_with?("git/gitconfig")
  end

  def test_home_path_returns_path_under_home
    path = @config.home_path(".config", "nvim")

    assert_equal File.join(Dir.home, ".config", "nvim"), path
  end

  def test_skills_source_root_uses_matt_pocock_layout
    assert_equal @config.dotfiles_path("skills"), @config.skills_source_root
  end

  def test_opencode_skills_target_points_to_user_skill_directory
    assert_equal @config.home_path(".config", "opencode", "skill"), @config.opencode_skills_target
  end

  def test_skills_manifest_path_points_to_repo_manifest
    assert_equal @config.dotfiles_path("skills.yml"), @config.skills_manifest_path
  end

  def test_local_skills_returns_explicit_manifest_paths
    assert_includes @config.local_skills, "engineering/commit-writer"
    assert_includes @config.local_skills, "engineering/reviewer"
  end
end
