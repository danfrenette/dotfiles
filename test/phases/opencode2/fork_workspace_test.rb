# frozen_string_literal: true

require "test_helper"
require "phases/opencode2"

class OpenCode2ForkWorkspaceTest < DotfilesTestCase
  def setup
    super
    @checkout = tmp_path("home/code/opencode")
    @git = "/usr/bin/git"
    @bun = "/opt/homebrew/bin/bun"
  end

  def test_plan_owns_clone_dependencies_and_live_web_commands
    plan = build_workspace.plan

    assert_equal [
      @git, "clone", "--branch", "dan-dev", "--single-branch",
      "https://github.com/danfrenette/opencode.git", @checkout
    ], plan.source_command
    assert_equal [@bun, "install", "--frozen-lockfile", "--cwd", @checkout], plan.dependency_command
    assert_equal [@bun, "run", "--cwd", @checkout, "dev:web:live"], plan.launch_command
  end

  def test_missing_tools_and_old_bun_fail_during_planning
    cases = [
      [{}, {}, "Git not found"],
      [{"git" => @git}, {}, "Bun not found"],
      [{"git" => @git, "bun" => @bun}, {"bun" => "1.2.22\n"}, "Bun 1.3 or newer is required; found 1.2.22"]
    ]

    cases.each do |executables, captures, expected|
      runner = TestCommandRunner.new(executables: executables, captures: captures)

      error = assert_raises(Phases::OpenCode2::Error) { build_workspace(runner).plan }

      assert_includes error.message, expected
    end
  end

  def test_apply_clones_validates_and_installs_frozen_dependencies
    runner = TestCommandRunner.new(
      executables: {"git" => @git, "bun" => @bun},
      on_run: lambda do |command, _options|
        create_opencode_fork(@checkout) if command.first == @git
      end
    )
    workspace = build_workspace(runner)

    workspace.apply(workspace.plan)

    assert_equal [
      [
        @git, "clone", "--branch", "dan-dev", "--single-branch",
        "https://github.com/danfrenette/opencode.git", @checkout
      ],
      [@bun, "install", "--frozen-lockfile", "--cwd", @checkout]
    ], runner.calls
  end

  def test_existing_checkout_uses_explicit_fast_forward_update
    create_opencode_fork(@checkout, git: true)
    plan = build_workspace.plan

    assert_equal [
      @git, "-C", @checkout, "pull", "--ff-only",
      "https://github.com/danfrenette/opencode.git", "dan-dev"
    ], plan.source_command
  end

  def test_unwritable_git_metadata_fails_before_commands
    create_opencode_fork(@checkout, git: true)
    objects = File.join(@checkout, ".git", "objects")
    FileUtils.chmod(0o500, objects)
    runner = TestCommandRunner.new(executables: {"git" => @git, "bun" => @bun})

    error = assert_raises(Phases::OpenCode2::Error) { build_workspace(runner).plan }

    assert_equal "OpenCode fork Git metadata is not writable: #{objects}", error.message
    assert_empty runner.calls
  ensure
    FileUtils.chmod(0o700, objects) if objects && File.exist?(objects)
  end

  def test_invalid_live_web_contract_skips_dependency_installation
    runner = TestCommandRunner.new(
      executables: {"git" => @git, "bun" => @bun},
      on_run: lambda do |command, _options|
        next unless command.first == @git

        FileUtils.mkdir_p(File.join(@checkout, "packages/app/script"))
        File.write(File.join(@checkout, "package.json"), '{"scripts":{"dev:web:live":"test"}}')
        File.write(File.join(@checkout, "packages/app/script/dev-web-live.ts"), "")
      end
    )
    workspace = build_workspace(runner)

    error = assert_raises(Phases::OpenCode2::Error) { workspace.apply(workspace.plan) }

    assert_equal "OpenCode fork dev:web:live does not use the expected proxy launcher", error.message
    assert_equal 1, runner.calls.length
  end

  def test_checkout_command_failure_skips_dependency_installation
    runner = TestCommandRunner.new(result: false, executables: {"git" => @git, "bun" => @bun})
    workspace = build_workspace(runner)

    error = assert_raises(Phases::OpenCode2::Error) { workspace.apply(workspace.plan) }

    assert_equal "OpenCode fork checkout exited with a nonzero status", error.message
    assert_equal 1, runner.calls.length
  end

  private

  def build_workspace(runner = TestCommandRunner.new(executables: {"git" => @git, "bun" => @bun}))
    Phases::OpenCode2::ForkWorkspace.new(checkout: @checkout, command_runner: runner)
  end
end
