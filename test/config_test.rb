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
end
