# frozen_string_literal: true

require "test_helper"
require "phases/skills"

class SkillsPhaseTest < DotfilesTestCase
  def setup
    super
    @reporter = Reporters::TestReporter.new
    @catalog_path = create_file("default-skills.yml", <<~YAML)
      catalogs:
        - source: owner/default
          skills: "*"
    YAML
    use_reporter(@reporter)
  end

  def test_plan_reports_the_pinned_global_catalog_handoff
    catalog = create_file("skills.yml", <<~YAML)
      catalogs:
        - source: owner/first
          skills: "*"
        - source: owner/second
          skills:
            - alpha
            - beta
    YAML
    phase = build_phase(executables: {"pnpm" => "/fake/pnpm"}, catalog_path: catalog)

    plan = phase.prepare.plan

    assert_equal [
      [
        "/fake/pnpm", "dlx", "skills@1.5.23", "add", "owner/first",
        "--global", "--agent", "opencode", "cursor", "--skill", "*", "--yes"
      ],
      [
        "/fake/pnpm", "dlx", "skills@1.5.23", "add", "owner/second",
        "--global", "--agent", "opencode", "cursor", "--skill", "alpha", "beta", "--yes"
      ]
    ], plan.commands
    assert_equal :skills, @reporter.planned_actions.last[:label]
    assert_predicate plan, :frozen?
  end

  def test_missing_package_manager_fails_during_planning
    error = assert_raises(Phases::Skills::Error) { build_phase.prepare }

    assert_equal "pnpm not found; run dotfiles setup before refresh", error.message
  end

  def test_apply_distinguishes_command_failure_from_failure_to_start
    [false, nil].each do |result|
      runner = TestCommandRunner.new(result: result, executables: {"pnpm" => "/fake/pnpm"})
      phase = build_phase(command_runner: runner)

      error = assert_raises(Phases::Skills::Error) { phase.prepare.apply }

      assert_equal(result.nil? ? "skills installation could not start" : "skills installation exited with a nonzero status", error.message)
    end
  end

  def test_apply_runs_catalogs_in_order_and_stops_on_failure
    catalog = create_file("skills.yml", <<~YAML)
      catalogs:
        - source: owner/first
          skills: "*"
        - source: owner/second
          skills: beta
        - source: owner/third
          skills: gamma
    YAML
    runner = TestCommandRunner.new(results: [true, false], executables: {"pnpm" => "/fake/pnpm"})
    phase = build_phase(command_runner: runner, catalog_path: catalog)

    error = assert_raises(Phases::Skills::Error) { phase.prepare.apply }

    assert_equal "skills installation exited with a nonzero status", error.message
    assert_equal [
      [
        "/fake/pnpm", "dlx", "skills@1.5.23", "add", "owner/first",
        "--global", "--agent", "opencode", "cursor", "--skill", "*", "--yes"
      ],
      [
        "/fake/pnpm", "dlx", "skills@1.5.23", "add", "owner/second",
        "--global", "--agent", "opencode", "cursor", "--skill", "beta", "--yes"
      ]
    ], runner.calls
  end

  private

  def build_phase(executables: {}, command_runner: nil, catalog_path: @catalog_path)
    runner = command_runner || TestCommandRunner.new(executables: executables)
    Phases::Skills.new(
      package_manager_candidates: ["/fake/pnpm"],
      command_runner: runner,
      catalog_path: catalog_path
    )
  end
end
