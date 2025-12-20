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

  def test_mappings_is_empty_initially
    assert_empty @config.mappings
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
