# frozen_string_literal: true

require "test_helper"
require "open3"
require "rbconfig"
require "bundler"

class InstallTest < DotfilesTestCase
  def test_help_prints_usage_and_exits_successfully
    stdout, stderr, status = run_install("--help")

    assert status.success?
    assert_includes stdout, "Usage: install.rb [options]"
    assert_includes stdout, "--dry-run"
    assert_includes stdout, "--yes"
    assert_includes stdout, "--only"
    assert_includes stdout, "--skip-brew"
    assert_includes stdout, "--skills-only"
    assert_includes stdout, "--update-skills"
    assert_empty stderr
  end

  def test_mappings_dry_run_prints_plan_and_exits_successfully
    home = create_dir("home")
    create_repo_link(home: home, source: "git/gitconfig", target: ".gitconfig")

    stdout, stderr, status = run_install("--only", "mappings", "--dry-run", home: home)

    assert status.success?
    assert_includes stdout, "git/gitconfig"
    assert_includes stdout, "unchanged"
    refute_includes stdout, "[???]"
    assert_includes stdout, "Dry run complete!"
    assert_empty stderr
  end

  def test_unsupported_phase_prints_help_and_exits_with_usage_error
    stdout, stderr, status = run_install("--only", "brew")

    assert_equal 64, status.exitstatus
    assert_empty stdout
    assert_includes stderr, "Unsupported phase: brew"
    assert_includes stderr, "Usage: install.rb [options]"
  end

  def test_conflicting_phase_selectors_exit_with_usage_error
    stdout, stderr, status = run_install("--only", "mappings", "--skills-only")

    assert_equal 64, status.exitstatus
    assert_empty stdout
    assert_includes stderr, "--only and --skills-only cannot be combined"
  end

  def test_declined_confirmation_exits_successfully_without_changes
    home = create_dir("home")

    stdout, stderr, status = run_install("--only", "mappings", stdin_data: "n\n", home: home)

    assert status.success?
    assert_includes stdout, "Apply this plan? [y/N]"
    refute File.exist?(File.join(home, ".gitconfig"))
    assert_empty stderr
  end

  def test_yes_applies_mappings_without_prompting
    home = create_dir("home")

    stdout, stderr, status = run_install("--only", "mappings", "--yes", home: home)

    assert status.success?
    refute_includes stdout, "Apply this plan?"
    assert_symlink File.join(home, ".gitconfig"), to: File.expand_path("../git/gitconfig", __dir__)
    assert_empty stderr
  end

  def test_positional_arguments_exit_with_usage_error
    stdout, stderr, status = run_install("unexpected")

    assert_equal 64, status.exitstatus
    assert_empty stdout
    assert_includes stderr, "Unexpected arguments: unexpected"
  end

  private

  def run_install(*arguments, stdin_data: "", home: nil)
    install = File.expand_path("../install.rb", __dir__)
    environment = {}
    environment["HOME"] = home if home
    Bundler.with_unbundled_env do
      Open3.capture3(environment, RbConfig.ruby, install, *arguments, stdin_data: stdin_data)
    end
  end
end
