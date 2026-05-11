# frozen_string_literal: true

require "test_helper"
require "installer"
require "reporters/test_reporter"

class InstallerTest < DotfilesTestCase
  def setup
    super
    @reporter = Reporters::TestReporter.new
    @mock_linker = MockLinker.new
    @mock_config = MockConfig.new
    @mock_skill_installer = MockSkillInstaller.new
  end

  def test_installer_responds_to_install
    installer = build_installer(skip_brew: true)
    assert_respond_to installer, :install
  end

  def test_install_reports_linking_phase
    build_installer(skip_brew: true).install
    assert_includes @reporter.phases, "Linking dotfiles"
  end

  def test_install_reports_post_install_phase
    build_installer(skip_brew: true).install
    assert_includes @reporter.phases, "Post-install"
  end

  def test_install_reports_skills_phase
    build_installer(skip_brew: true).install
    assert_includes @reporter.phases, "Installing skills"
  end

  def test_install_links_each_mapping
    build_installer(skip_brew: true).install
    assert_equal @mock_config.mappings.keys, @mock_linker.linked_sources
  end

  def test_install_reports_linked_actions
    build_installer(skip_brew: true).install
    assert_includes @reporter.action_types, :linked
  end

  def test_install_reports_completion
    build_installer(skip_brew: true).install
    assert @reporter.completion_reported
  end

  def test_install_installs_skills
    build_installer(skip_brew: true).install
    assert @mock_skill_installer.installed
  end

  def test_skills_only_installs_skills_without_linking_dotfiles
    build_installer(skip_brew: false, skills_only: true).install

    assert @mock_skill_installer.installed
    assert_empty @mock_linker.linked_sources
    assert_includes @reporter.phases, "Installing skills"
    refute_includes @reporter.phases, "Linking dotfiles"
    refute_includes @reporter.phases, "Post-install"
  end

  def test_dry_run_reports_would_replace_actions
    @mock_linker.result = :would_replace
    build_installer(skip_brew: true, dry_run: true).install

    assert_includes @reporter.action_types, :would_replace
    assert @reporter.dry_completion_reported
  end

  private

  def build_installer(skip_brew:, dry_run: false, skills_only: false)
    Installer.new(
      reporter: @reporter,
      skip_brew: skip_brew,
      dry_run: dry_run,
      skills_only: skills_only,
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
