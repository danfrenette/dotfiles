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
    assert_includes stdout, "Run only the named phase (repeatable)"
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

  def test_homebrew_dry_run_parses_and_prints_exact_plan
    bin = create_dir("bin")
    brew = create_executable(bin, "brew")

    stdout, stderr, status = run_install("--only", "homebrew", "--dry-run", path: bin)

    assert status.success?, stderr
    assert_includes stdout, "Homebrew executable: #{brew}"
    assert_includes stdout, "#{brew} bundle --file=#{File.expand_path("../Brewfile", __dir__)}"
    assert_includes stdout, "Dry run complete!"
    assert_empty stderr
  end

  def test_opencode2_dry_run_prints_base_and_personal_fork_plan
    bin = create_dir("bin")
    create_executable(bin, "pnpm")
    create_executable(bin, "git")
    bun = File.join(bin, "bun")
    File.write(bun, "#!/bin/sh\necho 1.3.14\n")
    FileUtils.chmod("+x", bun)
    home = create_dir("home")

    stdout, stderr, status = run_install("--only", "opencode2", "--dry-run", home: home, path: bin)

    assert status.success?, stderr
    assert_includes stdout, "@opencode-ai/cli@next (prerelease channel: next)"
    assert_includes stdout, File.join(home, ".local", "bin", "opencode2")
    assert_includes stdout, "https://github.com/danfrenette/opencode.git"
    assert_includes stdout, "dan-dev"
    assert_includes stdout, "#{File.join(home, ".local", "bin", "opencode2")} service start"
    assert_includes stdout, "dev:web:live"
    refute File.exist?(File.join(home, ".local"))
    refute File.exist?(File.join(home, "code"))
  end

  def test_unsupported_phase_prints_help_and_exits_with_usage_error
    stdout, stderr, status = run_install("--only", "brew")

    assert_equal 64, status.exitstatus
    assert_empty stdout
    assert_includes stderr, "Unsupported phase: brew"
    assert_includes stderr, "Usage: install.rb [options]"
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
