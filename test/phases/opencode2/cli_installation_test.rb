# frozen_string_literal: true

require "test_helper"
require "phases/opencode2"

class OpenCode2CLIInstallationTest < DotfilesTestCase
  def setup
    super
    @global_dir = tmp_path("home/.local/share/pnpm/global")
    @bin_dir = tmp_path("home/.local/bin")
    @executable = File.join(@bin_dir, "opencode2")
    @pnpm = "/opt/homebrew/bin/pnpm"
  end

  def test_plan_owns_package_destinations_and_exact_commands
    plan = build_installation.plan

    assert_equal "@opencode-ai/cli@next", plan.package_specification
    assert_equal "next", plan.channel
    assert_equal @executable, plan.executable
    assert_equal [
      @pnpm, "add", "--global", "--global-dir=#{@global_dir}",
      "--global-bin-dir=#{@bin_dir}", "@opencode-ai/cli@next"
    ], plan.install_command
    assert_equal [@executable, "--version"], plan.verification_command
    assert_equal [@executable, "service", "start"], plan.service_command
    assert_equal "#{@bin_dir}#{File::PATH_SEPARATOR}#{ENV.fetch("PATH", "")}", plan.environment.fetch("PATH")
  end

  def test_apply_creates_destinations_installs_and_verifies_exact_executable
    runner = TestCommandRunner.new(
      executables: {"pnpm" => @pnpm},
      on_run: lambda do |command, _options|
        next unless command.first == @pnpm

        FileUtils.mkdir_p(@bin_dir)
        File.write(@executable, "#!/bin/sh\n")
        FileUtils.chmod("+x", @executable)
      end
    )
    installation = build_installation(runner)
    plan = installation.plan

    installation.apply(plan)

    assert File.directory?(@global_dir)
    assert File.directory?(@bin_dir)
    assert_equal @executable, runner.calls.last.first
    assert_equal [@executable, "--version"], runner.calls.last
  end

  def test_missing_durable_pnpm_fails_before_mutation
    error = assert_raises(Phases::OpenCode2::Error) do
      build_installation(TestCommandRunner.new).plan
    end

    assert_includes error.message, "pnpm not found"
    refute File.exist?(tmp_path("home/.local"))
  end

  def test_invalid_destination_fails_during_planning
    blocker = create_file("home/.local")

    error = assert_raises(Phases::OpenCode2::Error) { build_installation.plan }

    assert_equal "OpenCode2 destination has a non-directory component: #{blocker}", error.message
  end

  def test_package_failure_skips_verification
    runner = TestCommandRunner.new(result: false, executables: {"pnpm" => @pnpm})
    installation = build_installation(runner)

    error = assert_raises(Phases::OpenCode2::Error) { installation.apply(installation.plan) }

    assert_equal "OpenCode2 installation exited with a nonzero status", error.message
    assert_equal 1, runner.calls.length
  end

  def test_unrelated_executable_cannot_satisfy_exact_verification
    runner = TestCommandRunner.new(executables: {"pnpm" => @pnpm, "opencode2" => "/unrelated/opencode2"})
    installation = build_installation(runner)

    error = assert_raises(Phases::OpenCode2::Error) { installation.apply(installation.plan) }

    assert_equal "OpenCode2 executable was not installed at #{@executable}", error.message
    assert_equal 1, runner.calls.length
  end

  def test_nonzero_exact_verification_fails
    runner = TestCommandRunner.new(
      results: [true, false],
      executables: {"pnpm" => @pnpm},
      on_run: lambda do |command, _options|
        next unless command.first == @pnpm

        FileUtils.mkdir_p(@bin_dir)
        File.write(@executable, "#!/bin/sh\n")
        FileUtils.chmod("+x", @executable)
      end
    )
    installation = build_installation(runner)

    error = assert_raises(Phases::OpenCode2::Error) { installation.apply(installation.plan) }

    assert_equal "OpenCode2 verification exited with a nonzero status", error.message
    assert_equal [@executable, "--version"], runner.calls.last
  end

  private

  def build_installation(runner = TestCommandRunner.new(executables: {"pnpm" => @pnpm}))
    Phases::OpenCode2::CLIInstallation.new(
      global_dir: @global_dir,
      bin_dir: @bin_dir,
      package_manager_candidates: [@pnpm],
      command_runner: runner
    )
  end
end
