# frozen_string_literal: true

require "test_helper"
require "open3"
require "rbconfig"
require "bundler"

class InstallTest < DotfilesTestCase
  def test_help_prints_commands_and_exits_successfully
    stdout, stderr, status = run_install("--help")

    assert status.success?
    assert_includes stdout, "Usage: install.rb COMMAND [options]"
    assert_includes stdout, "setup"
    assert_includes stdout, "refresh"
    assert_includes stdout, "--dry-run"
    assert_empty stderr
  end

  def test_missing_command_prints_help_and_exits_with_usage_error
    stdout, stderr, status = run_install

    assert_equal 64, status.exitstatus
    assert_empty stdout
    assert_includes stderr, "COMMAND must be setup or refresh"
    assert_includes stderr, "Usage: install.rb COMMAND [options]"
  end

  def test_unknown_command_prints_help_and_exits_with_usage_error
    stdout, stderr, status = run_install("update")

    assert_equal 64, status.exitstatus
    assert_empty stdout
    assert_includes stderr, "unknown command: update"
  end

  def test_setup_dry_run_reports_desired_lifecycle_without_future_executables
    home = create_dir("home")
    bin = create_dir("bin")
    create_executable(bin, "brew")

    stdout, stderr, status = run_install("setup", "--dry-run", home: home, path: bin)

    assert status.success?, stderr
    assert_includes stdout, "Setup workflow"
    assert_includes stdout, "homebrew: Install baseline packages"
    assert_includes stdout, "opencode2: Install OpenCode2"
    assert_includes stdout, "mappings: Link dotfiles"
    assert_includes stdout, "skills: Install agent skills"
    assert_includes stdout, "neovim: Install Neovim plugins"
    assert_includes stdout, "Dry run complete!"
    assert_empty stderr
  end

  def test_refresh_dry_run_reports_dotfiles_and_skills_only
    home = create_dir("home")
    bin = create_dir("bin")
    create_executable(bin, "pnpm")
    create_repo_link(home: home, source: "git/gitconfig", target: ".gitconfig")

    stdout, stderr, status = run_install("refresh", "--dry-run", home: home, path: bin)

    assert status.success?, stderr
    assert_includes stdout, "Refresh workflow"
    assert_includes stdout, "git/gitconfig"
    assert_includes stdout, "Installing skills"
    refute_includes stdout, "Installing Neovim plugins"
    assert_empty stderr
  end

  def test_declined_refresh_exits_without_changes
    home = create_dir("home")
    bin = create_dir("bin")
    create_executable(bin, "pnpm")

    stdout, stderr, status = run_install("refresh", stdin_data: "n\n", home: home, path: bin)

    assert status.success?, stderr
    assert_includes stdout, "Apply this plan? [y/N]"
    refute File.exist?(File.join(home, ".gitconfig"))
  end

  def test_yes_applies_refresh_without_prompting
    home = create_dir("home")
    bin = create_dir("bin")
    create_executable(bin, "pnpm")

    stdout, stderr, status = run_install("refresh", "--yes", home: home, path: bin)

    assert status.success?, stderr
    refute_includes stdout, "Apply this plan?"
    assert_symlink File.join(home, ".gitconfig"), to: File.expand_path("../git/gitconfig", __dir__)
  end

  private

  def create_executable(bin, name)
    path = File.join(bin, name)
    File.write(path, "#!/bin/sh\nexit 0\n")
    FileUtils.chmod("+x", path)
    path
  end

  def run_install(*arguments, stdin_data: "", home: nil, path: nil)
    install = File.expand_path("../install.rb", __dir__)
    environment = {}
    environment["HOME"] = home if home
    environment["PATH"] = path if path
    Bundler.with_unbundled_env do
      Open3.capture3(environment, RbConfig.ruby, install, *arguments, stdin_data: stdin_data)
    end
  end
end
