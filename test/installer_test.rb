# frozen_string_literal: true

require "test_helper"
require "installer"

class InstallerTest < DotfilesTestCase
  def setup
    super
    @output = StringIO.new
    @mock_linker = MockLinker.new
    @mock_config = MockConfig.new
    @mock_skill_installer = MockSkillInstaller.new
  end

  def test_installer_responds_to_install
    installer = build_installer(skip_brew: true)
    assert_respond_to installer, :install
  end

  def test_install_outputs_linking_header
    build_installer(skip_brew: true).install
    assert_match(/Linking dotfiles/, @output.string)
  end

  def test_install_outputs_post_install_header
    build_installer(skip_brew: true).install
    assert_match(/Post-install/, @output.string)
  end

  def test_install_outputs_skills_header
    build_installer(skip_brew: true).install
    assert_match(/Installing skills/, @output.string)
  end

  def test_install_links_each_mapping
    build_installer(skip_brew: true).install
    assert_equal @mock_config.mappings.keys, @mock_linker.linked_sources
  end

  def test_install_logs_linked_files
    build_installer(skip_brew: true).install
    assert_match(/\[LINK\]/, @output.string)
  end

  def test_install_logs_completion_message
    build_installer(skip_brew: true).install
    assert_match(/Installation complete!/, @output.string)
  end

  def test_install_installs_skills
    build_installer(skip_brew: true).install
    assert @mock_skill_installer.installed
  end

  def test_dry_run_logs_replace_and_backup_actions
    @mock_linker.result = :would_replace
    build_installer(skip_brew: true, dry_run: true).install

    assert_match(/would back up .*\.backup/, @output.string)
    assert_match(/would replace/, @output.string)
    assert_match(/Dry run complete!/, @output.string)
  end

  private

  def build_installer(skip_brew:, dry_run: false)
    Installer.new(
      output: @output,
      skip_brew: skip_brew,
      dry_run: dry_run,
      linker: @mock_linker,
      config: @mock_config,
      skill_installer: @mock_skill_installer
    )
  end

  class MockLinker
    attr_accessor :result
    attr_reader :linked_sources

    def initialize
      @linked_sources = []
      @result = :linked
    end

    def link(source, _target)
      @linked_sources << source
      result
    end
  end

  class MockSkillInstaller
    attr_reader :installed

    def install
      @installed = true
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
