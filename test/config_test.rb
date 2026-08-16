# frozen_string_literal: true

require "test_helper"

class ConfigTest < DotfilesTestCase
  def setup
    super
    @config = Config.new
  end

  def test_mappings_returns_hash
    assert_instance_of Hash, @config.mappings
  end

  def test_mappings_includes_git_configs
    mappings = @config.mappings

    assert mappings.key?(@config.dotfiles_path("git", "gitconfig"))
    assert mappings.key?(@config.dotfiles_path("git", "gitignore"))
    assert mappings.key?(@config.dotfiles_path("git", "gitmessage"))
    assert mappings.key?(@config.dotfiles_path("git", "ignore"))
  end

  def test_git_mappings_point_to_correct_targets
    mappings = @config.mappings

    assert_equal @config.home_path(".gitconfig"), mappings[@config.dotfiles_path("git", "gitconfig")]
    assert_equal @config.home_path(".gitignore"), mappings[@config.dotfiles_path("git", "gitignore")]
    assert_equal @config.home_path(".gitmessage"), mappings[@config.dotfiles_path("git", "gitmessage")]
    assert_equal @config.home_path(".config", "git", "ignore"), mappings[@config.dotfiles_path("git", "ignore")]
  end

  def test_mappings_includes_zsh_configs
    mappings = @config.mappings

    assert mappings.key?(@config.dotfiles_path("zsh", "zshrc"))
    assert mappings.key?(@config.dotfiles_path("zsh", "zprofile"))
  end

  def test_zsh_mappings_point_to_correct_targets
    mappings = @config.mappings

    assert_equal @config.home_path(".zshrc"), mappings[@config.dotfiles_path("zsh", "zshrc")]
    assert_equal @config.home_path(".zprofile"), mappings[@config.dotfiles_path("zsh", "zprofile")]
  end

  def test_mappings_includes_nvim_configs
    mappings = @config.mappings

    assert mappings.key?(@config.dotfiles_path("config", "nvim", "init.lua"))
    assert mappings.key?(@config.dotfiles_path("config", "nvim", "lua", "options.lua"))
    assert mappings.key?(@config.dotfiles_path("config", "nvim", "lua", "keymaps.lua"))
    assert mappings.key?(@config.dotfiles_path("config", "nvim", "lua", "plugins.lua"))
    assert mappings.key?(@config.dotfiles_path("config", "nvim", "lua", "autocmds.lua"))
  end

  def test_nvim_mappings_point_to_correct_targets
    mappings = @config.mappings

    assert_equal @config.home_path(".config", "nvim", "init.lua"),
      mappings[@config.dotfiles_path("config", "nvim", "init.lua")]
    assert_equal @config.home_path(".config", "nvim", "lua", "options.lua"),
      mappings[@config.dotfiles_path("config", "nvim", "lua", "options.lua")]
  end

  def test_mappings_include_ghostty_config
    mappings = @config.mappings

    assert mappings.key?(@config.dotfiles_path("config", "ghostty", "config"))
  end

  def test_ghostty_mapping_points_to_correct_target
    mappings = @config.mappings

    assert_equal @config.home_path(".config", "ghostty", "config"),
      mappings[@config.dotfiles_path("config", "ghostty", "config")]
  end

  def test_all_mapping_sources_are_absolute_paths
    @config.mappings.each_key do |source|
      assert source.start_with?("/"), "Source path should be absolute: #{source}"
    end
  end

  def test_all_mapping_targets_are_absolute_paths
    @config.mappings.each_value do |target|
      assert target.start_with?("/"), "Target path should be absolute: #{target}"
    end
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
