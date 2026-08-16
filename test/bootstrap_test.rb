# frozen_string_literal: true

require "test_helper"
require "open3"
require "bundler"

class BootstrapTest < DotfilesTestCase
  def test_uses_repository_ruby_and_forwards_installer_arguments
    bin = create_dir("bin")
    log = tmp_path("commands.log")
    create_fake_brew(bin)
    create_fake_rbenv(bin)

    environment = {
      "COMMAND_LOG" => log,
      "FAKE_BIN" => bin,
      "HOME" => create_dir("home"),
      "PATH" => "#{bin}:/usr/bin:/bin",
      "RBENV_VERSION" => nil,
      "INSTALLED_RUBY" => "4.0.3"
    }
    bootstrap = File.expand_path("../bootstrap.sh", __dir__)

    _stdout, stderr, status = Bundler.with_unbundled_env do
      Open3.capture3(
        environment,
        "bash",
        bootstrap,
        "--only",
        "mappings",
        "--dry-run",
        chdir: create_dir("caller")
      )
    end

    assert status.success?, stderr
    assert_includes File.readlines(log, chomp: true),
      "RBENV_VERSION=4.0.3 rbenv exec ruby #{File.expand_path("../install.rb", __dir__)} --only mappings --dry-run"
    refute File.readlines(log, chomp: true).any? { |line| line.match?(/brew (install|upgrade)|rbenv install/) }
  end

  def test_missing_homebrew_runs_official_installer_in_normal_mode
    bin = create_dir("bin")
    log = tmp_path("commands.log")
    brew_template = tmp_path("brew-template")
    create_fake_brew(File.dirname(brew_template), File.basename(brew_template))
    create_fake_curl(bin, install_script: <<~SH)
      echo "homebrew installer" >> "$COMMAND_LOG"
      cp "$FAKE_BREW_TEMPLATE" "$FAKE_BIN/brew"
      chmod +x "$FAKE_BIN/brew"
    SH
    create_fake_rbenv(bin)

    _stdout, stderr, status = run_bootstrap(
      base_environment(bin, log).merge(
        "FAKE_BREW_TEMPLATE" => brew_template,
        "HOMEBREW_CANDIDATES" => tmp_path("missing-brew"),
        "INSTALLED_RUBY" => "4.0.3"
      )
    )

    assert status.success?, stderr
    assert_includes File.readlines(log, chomp: true), "curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh"
    assert_includes File.readlines(log, chomp: true), "homebrew installer"
  end

  def test_homebrew_still_missing_after_installer_exits_nonzero
    bin = create_dir("bin")
    log = tmp_path("commands.log")
    create_fake_curl(bin, install_script: "echo installer-ran >> \"$COMMAND_LOG\"")

    _stdout, stderr, status = run_bootstrap(
      base_environment(bin, log).merge("HOMEBREW_CANDIDATES" => tmp_path("missing-brew"))
    )

    refute status.success?
    assert_includes stderr, "Homebrew installation could not be located"
  end

  def test_failed_homebrew_installer_exits_nonzero
    bin = create_dir("bin")
    log = tmp_path("commands.log")
    create_fake_curl(bin, install_script: "exit 42")

    _stdout, stderr, status = run_bootstrap(
      base_environment(bin, log).merge("HOMEBREW_CANDIDATES" => tmp_path("missing-brew"))
    )

    refute status.success?
    assert_includes stderr, "Homebrew installation failed"
  end

  def test_missing_homebrew_dry_run_reports_without_running_installer
    bin = create_dir("bin")
    log = tmp_path("commands.log")
    create_fake_curl(bin, install_script: "echo installer-ran >> \"$COMMAND_LOG\"")

    stdout, stderr, status = run_bootstrap(
      base_environment(bin, log).merge("HOMEBREW_CANDIDATES" => tmp_path("missing-brew")),
      "--only", "homebrew", "--dry-run"
    )

    assert status.success?, stderr
    assert_includes stdout, "Would install Homebrew with the official installer"
    refute File.exist?(log)
    refute_includes stdout, "Running installer with Ruby"
  end

  def test_missing_rbenv_dry_run_reports_without_installing
    bin = create_dir("bin")
    log = tmp_path("commands.log")
    create_fake_brew(bin)

    stdout, stderr, status = run_bootstrap(
      base_environment(bin, log).merge("MISSING_FORMULA" => "rbenv"),
      "--dry-run"
    )

    assert status.success?, stderr
    assert_includes stdout, "Would install Homebrew formula: rbenv"
    refute File.readlines(log, chomp: true).any? { |line| line.match?(/brew (install|upgrade)/) }
    refute_includes stdout, "Running installer with Ruby"
  end

  def test_unavailable_rbenv_dry_run_reports_reinstall_without_mutating
    bin = create_dir("bin")
    log = tmp_path("commands.log")
    create_fake_brew(bin)

    stdout, stderr, status = run_bootstrap(base_environment(bin, log), "--dry-run")

    assert status.success?, stderr
    assert_includes stdout, "Would reinstall Homebrew formula: rbenv"
    refute File.readlines(log, chomp: true).any? { |line| line.match?(/brew (install|reinstall|upgrade)/) }
    refute_includes stdout, "Running installer with Ruby"
  end

  def test_failed_homebrew_shellenv_stops_bootstrap
    bin = create_dir("bin")
    log = tmp_path("commands.log")
    create_fake_brew(bin)

    _stdout, stderr, status = run_bootstrap(
      base_environment(bin, log).merge("FAIL_SHELLENV" => "1", "INSTALLED_RUBY" => "4.0.3"),
      "--dry-run"
    )

    refute status.success?
    assert_includes stderr, "Homebrew shell environment could not be loaded"
    refute File.readlines(log, chomp: true).any? { |line| line.start_with?("rbenv ") }
  end

  def test_missing_ruby_dry_run_reports_without_installing
    bin = create_dir("bin")
    log = tmp_path("commands.log")
    create_fake_brew(bin)
    create_fake_rbenv(bin)

    stdout, stderr, status = run_bootstrap(base_environment(bin, log), "--dry-run")

    assert status.success?, stderr
    assert_includes stdout, "Would install Ruby 4.0.3 with rbenv"
    refute File.readlines(log, chomp: true).any? { |line| line.match?(/brew (install|upgrade)|rbenv install/) }
    refute_includes stdout, "Running installer with Ruby"
  end

  def test_installs_missing_rbenv_and_updates_missing_ruby_definition
    bin = create_dir("bin")
    log = tmp_path("commands.log")
    create_fake_brew(bin)
    create_fake_rbenv(bin)
    environment = {
      "COMMAND_LOG" => log,
      "FAKE_BIN" => bin,
      "HOME" => create_dir("home"),
      "PATH" => "#{bin}:/usr/bin:/bin",
      "MISSING_FORMULA" => "rbenv",
      "MISSING_RUBY_DEFINITION" => "1"
    }

    _stdout, stderr, status = run_bootstrap(environment)

    assert status.success?, stderr
    assert_includes File.readlines(log, chomp: true), "brew install rbenv"
    assert_includes File.readlines(log, chomp: true), "brew upgrade ruby-build"
  end

  def test_existing_repository_ruby_skips_package_and_ruby_installation
    bin = create_dir("bin")
    log = tmp_path("commands.log")
    create_fake_brew(bin)
    create_fake_rbenv(bin)
    environment = {
      "COMMAND_LOG" => log,
      "FAKE_BIN" => bin,
      "HOME" => create_dir("home"),
      "PATH" => "#{bin}:/usr/bin:/bin",
      "INSTALLED_RUBY" => "4.0.3",
      "MISSING_FORMULA" => "ruby-build"
    }

    _stdout, stderr, status = run_bootstrap(environment)
    calls = File.readlines(log, chomp: true)

    assert status.success?, stderr
    refute calls.any? { |line| line.match?(/brew (install|upgrade)/) }
    refute calls.any? { |line| line.start_with?("rbenv install") }
    assert_includes calls,
      "RBENV_VERSION=4.0.3 rbenv exec ruby #{File.expand_path("../install.rb", __dir__)} --help"
  end

  def test_known_homebrew_candidates_apply_shellenv_to_current_process
    ["opt/homebrew/bin/brew", "usr/local/bin/brew"].each do |relative_candidate|
      bin = create_dir("bin-#{relative_candidate.tr("/", "-")}")
      log = tmp_path("#{relative_candidate.tr("/", "-")}.log")
      candidate = tmp_path(relative_candidate)
      FileUtils.mkdir_p(File.dirname(candidate))
      create_fake_brew(File.dirname(candidate), File.basename(candidate))
      create_fake_rbenv(bin)

      _stdout, stderr, status = run_bootstrap(
        base_environment(bin, log).merge(
          "HOMEBREW_CANDIDATES" => candidate,
          "INSTALLED_RUBY" => "4.0.3"
        )
      )

      assert status.success?, stderr
      assert_includes File.readlines(log, chomp: true), "brew shellenv"
      assert File.readlines(log, chomp: true).any? { |line| line.include?("SHELLENV_MARKER=loaded") }
    end
  end

  def test_normal_bootstrap_is_idempotent_when_prerequisites_exist
    bin = create_dir("bin")
    log = tmp_path("commands.log")
    create_fake_brew(bin)
    create_fake_rbenv(bin)
    environment = base_environment(bin, log).merge("INSTALLED_RUBY" => "4.0.3")

    2.times do
      _stdout, stderr, status = run_bootstrap(environment)
      assert status.success?, stderr
    end

    calls = File.readlines(log, chomp: true)
    refute calls.any? { |line| line.match?(/brew (install|reinstall|upgrade)|rbenv install/) }
    assert_equal 2, calls.count { |line| line.include?("rbenv exec ruby") }
  end

  private

  def create_fake_brew(bin, name = "brew")
    create_executable(bin, name, <<~SH)
      echo "brew $*" >> "$COMMAND_LOG"
      if [[ "$1" == "shellenv" ]]; then
        if [[ -n "${FAIL_SHELLENV:-}" ]]; then
          exit 1
        fi
        echo "export PATH=$FAKE_BIN:/usr/bin:/bin"
        echo "export SHELLENV_MARKER=loaded"
      elif [[ "$1" == "list" && "$3" == "${MISSING_FORMULA:-}" ]]; then
        exit 1
      fi
    SH
  end

  def create_fake_curl(bin, install_script:)
    create_executable(bin, "curl", <<~SH)
      echo "curl $*" >> "$COMMAND_LOG"
      cat <<'INSTALL_SCRIPT'
      #{install_script}
      INSTALL_SCRIPT
    SH
  end

  def create_fake_rbenv(bin)
    create_executable(bin, "rbenv", <<~SH)
      if [[ -n "${RBENV_VERSION:-}" ]]; then
        echo "RBENV_VERSION=$RBENV_VERSION rbenv $*" >> "$COMMAND_LOG"
      else
        echo "rbenv $*" >> "$COMMAND_LOG"
      fi
      echo "SHELLENV_MARKER=${SHELLENV_MARKER:-}" >> "$COMMAND_LOG"
      if [[ "$1 $2" == "versions --bare" && -n "${INSTALLED_RUBY:-}" ]]; then
        echo "$INSTALLED_RUBY"
      fi
      if [[ "$1 $2" == "install -l" && -z "${MISSING_RUBY_DEFINITION:-}" ]]; then
        echo "4.0.3"
      fi
    SH
  end

  def create_executable(bin, name, body)
    path = File.join(bin, name)
    File.write(path, "#!/bin/bash\nset -e\n#{body}")
    FileUtils.chmod("+x", path)
  end

  def base_environment(bin, log)
    {
      "COMMAND_LOG" => log,
      "FAKE_BIN" => bin,
      "HOME" => create_dir("home"),
      "PATH" => "#{bin}:/usr/bin:/bin"
    }
  end

  def run_bootstrap(environment, *arguments)
    bootstrap = File.expand_path("../bootstrap.sh", __dir__)
    Bundler.with_unbundled_env do
      Open3.capture3(environment, "bash", bootstrap, *(arguments.empty? ? ["--help"] : arguments))
    end
  end
end
