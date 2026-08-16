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
      "RBENV_VERSION" => nil
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
    assert_includes File.readlines(log, chomp: true), "rbenv install -s 4.0.3"
    assert_includes File.readlines(log, chomp: true),
      "RBENV_VERSION=4.0.3 rbenv exec ruby #{File.expand_path("../install.rb", __dir__)} --only mappings --dry-run"
    refute File.readlines(log, chomp: true).any? { |line| line.match?(/brew (install|upgrade)/) }
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
      "INSTALLED_RUBY" => "4.0.3"
    }

    _stdout, stderr, status = run_bootstrap(environment)
    calls = File.readlines(log, chomp: true)

    assert status.success?, stderr
    refute calls.any? { |line| line.match?(/brew (install|upgrade)/) }
    refute calls.any? { |line| line.start_with?("rbenv install") }
    assert_includes calls,
      "RBENV_VERSION=4.0.3 rbenv exec ruby #{File.expand_path("../install.rb", __dir__)} --help"
  end

  private

  def create_fake_brew(bin)
    create_executable(bin, "brew", <<~SH)
      echo "brew $*" >> "$COMMAND_LOG"
      if [[ "$1" == "shellenv" ]]; then
        echo "export PATH=$FAKE_BIN:/usr/bin:/bin"
      elif [[ "$1" == "list" && "$3" == "${MISSING_FORMULA:-}" ]]; then
        exit 1
      fi
    SH
  end

  def create_fake_rbenv(bin)
    create_executable(bin, "rbenv", <<~SH)
      if [[ -n "${RBENV_VERSION:-}" ]]; then
        echo "RBENV_VERSION=$RBENV_VERSION rbenv $*" >> "$COMMAND_LOG"
      else
        echo "rbenv $*" >> "$COMMAND_LOG"
      fi
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

  def run_bootstrap(environment)
    bootstrap = File.expand_path("../bootstrap.sh", __dir__)
    Bundler.with_unbundled_env do
      Open3.capture3(environment, "bash", bootstrap, "--help")
    end
  end
end
