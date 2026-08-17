# frozen_string_literal: true

require "test_helper"
require "phases/opencode2"
require "reporters/test_reporter"

class OpenCode2PhaseTest < DotfilesTestCase
  def test_reports_combined_plan_and_applies_cli_before_fork
    global_dir = tmp_path("home/.local/share/pnpm/global")
    bin_dir = tmp_path("home/.local/bin")
    executable = File.join(bin_dir, "opencode2")
    checkout = tmp_path("home/code/opencode")
    pnpm = "/fake/pnpm"
    git = "/fake/git"
    bun = "/fake/bun"
    reporter = Reporters::TestReporter.new
    runner = TestCommandRunner.new(
      executables: {"pnpm" => pnpm, "git" => git, "bun" => bun},
      on_run: lambda do |command, _options|
        if command.first == pnpm
          FileUtils.mkdir_p(bin_dir)
          File.write(executable, "#!/bin/sh\n")
          FileUtils.chmod("+x", executable)
        elsif command.first == git
          create_opencode_fork(checkout)
        end
      end
    )
    phase = Phases::OpenCode2::Phase.new(
      global_dir: global_dir,
      bin_dir: bin_dir,
      checkout: checkout,
      package_manager_candidates: [pnpm],
      command_runner: runner,
      reporter: reporter
    )

    plan = phase.plan
    phase.apply(plan)

    assert_equal ["Installing OpenCode2"], reporter.phases
    assert_equal [
      :package_manager, :package, :destination, :install, :verify,
      :source, :dependencies, :service, :workflow
    ], reporter.action_types
    assert_equal [pnpm, executable, git, bun], runner.calls.map(&:first)
  end
end
