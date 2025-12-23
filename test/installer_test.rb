# frozen_string_literal: true

require "test_helper"
require "installer"

class InstallerTest < DotfilesTestCase
  def setup
    super
    @output = StringIO.new
    @mock_linker = MockLinker.new
    @mock_config = MockConfig.new
  end

  def test_installer_responds_to_install
    installer = Installer.new(output: @output, skip_brew: true)
    assert_respond_to installer, :install
  end

  def test_install_outputs_linking_header
    installer = Installer.new(
      output: @output,
      skip_brew: true,
      linker: @mock_linker,
      config: @mock_config
    )
    installer.install
    assert_match(/Linking dotfiles/, @output.string)
  end

  def test_install_outputs_post_install_header
    installer = Installer.new(
      output: @output,
      skip_brew: true,
      linker: @mock_linker,
      config: @mock_config
    )
    installer.install
    assert_match(/Post-install/, @output.string)
  end

  def test_install_links_each_mapping
    installer = Installer.new(
      output: @output,
      skip_brew: true,
      linker: @mock_linker,
      config: @mock_config
    )
    installer.install
    assert_equal @mock_config.mappings.keys, @mock_linker.linked_sources
  end

  def test_install_logs_linked_files
    installer = Installer.new(
      output: @output,
      skip_brew: true,
      linker: @mock_linker,
      config: @mock_config
    )
    installer.install
    assert_match(/\[LINK\]/, @output.string)
  end

  def test_install_logs_completion_message
    installer = Installer.new(
      output: @output,
      skip_brew: true,
      linker: @mock_linker,
      config: @mock_config
    )
    installer.install
    assert_match(/Installation complete!/, @output.string)
  end

  # Mock objects for dependency injection
  class MockLinker
    attr_reader :linked_sources

    def initialize
      @linked_sources = []
    end

    def link(source, _target)
      @linked_sources << source
      :linked
    end
  end

  class MockConfig
    def mappings
      {
        "/tmp/dotfiles/gitconfig" => "/tmp/home/.gitconfig",
        "/tmp/dotfiles/zshrc" => "/tmp/home/.zshrc"
      }
    end

    def nvim_init_target
      "/nonexistent/path/init.lua"
    end

    def brewfile_path
      "/nonexistent/Brewfile"
    end
  end
end
