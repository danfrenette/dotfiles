# frozen_string_literal: true

require "test_helper"
require "phases/opencode2"

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

    phase.prepare.apply

    assert_equal ["Installing OpenCode2"], reporter.phases
    assert_equal %i[ok pkg dest run check service source deps ready],
      reporter.planned_actions.map { |action| action.fetch(:label) }
    assert_equal [pnpm, executable, executable, git, bun], runner.calls.map(&:first)
  end

  def test_plan_is_an_immutable_aggregate_class
    phase = Phases::OpenCode2::Phase.new(
      global_dir: tmp_path("home/.local/share/pnpm/global"),
      bin_dir: tmp_path("home/.local/bin"),
      checkout: tmp_path("home/code/opencode"),
      package_manager_candidates: ["/fake/pnpm"],
      command_runner: TestCommandRunner.new(
        executables: {"pnpm" => "/fake/pnpm", "git" => "/fake/git", "bun" => "/fake/bun"}
      ),
      reporter: Reporters::TestReporter.new
    )

    plan = phase.prepare.plan

    assert_instance_of Phases::OpenCode2::Plan, plan
    assert_instance_of Phases::OpenCode2::CLIInstallation::Plan, plan.cli
    assert_instance_of Phases::OpenCode2::ForkWorkspace::Plan, plan.fork
    assert_predicate plan, :frozen?
    assert_predicate plan.cli, :frozen?
    assert_predicate plan.fork, :frozen?
  end
end
