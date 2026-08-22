# frozen_string_literal: true

require "test_helper"
require "phases/skills"

class SkillsPhaseTest < DotfilesTestCase
  def setup
    super
    @reporter = Reporters::TestReporter.new
    use_reporter(@reporter)
  end

  def test_plan_reports_the_pinned_global_opencode_handoff
    phase = build_phase(executables: {"pnpm" => "/fake/pnpm"})

    plan = phase.prepare.plan

    assert_equal ["/fake/pnpm", "dlx", "skills@1.5.22", "add", "danfrenette/skills", "--global", "--agent", "opencode"], plan.command
    assert_equal :skills, @reporter.planned_actions.last[:label]
    assert_predicate plan, :frozen?
  end

  def test_missing_package_manager_fails_during_planning
    error = assert_raises(Phases::Skills::Error) { build_phase.prepare }

    assert_equal "pnpm not found; run ./install.rb setup before refresh", error.message
  end

  def test_apply_distinguishes_command_failure_from_failure_to_start
    [false, nil].each do |result|
      runner = TestCommandRunner.new(result: result, executables: {"pnpm" => "/fake/pnpm"})
      phase = build_phase(command_runner: runner)

      error = assert_raises(Phases::Skills::Error) { phase.prepare.apply }

      assert_equal(result.nil? ? "skills installation could not start" : "skills installation exited with a nonzero status", error.message)
    end
  end

  private

  def build_phase(executables: {}, command_runner: nil)
    runner = command_runner || TestCommandRunner.new(executables: executables)
    Phases::Skills.new(
      package_manager_candidates: ["/fake/pnpm"],
      command_runner: runner
    )
  end
end
