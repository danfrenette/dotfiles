# frozen_string_literal: true

require "test_helper"
require "phases/neovim"

class NeovimPhaseTest < DotfilesTestCase
  Availability = Struct.new(:targets)

  def setup
    super
    @targets = [tmp_path("home/.config/nvim/init.lua"), tmp_path("home/.config/nvim/lua/options.lua")]
    @reporter = Reporters::TestReporter.new
  end

  def test_plan_reports_absolute_executable_configuration_and_exact_command
    phase = build_phase(executables: {"nvim" => "/fake/nvim"})

    plan = phase.prepare.plan

    assert_equal "/fake/nvim", plan.executable
    assert_equal @targets, plan.configuration_targets
    assert_equal ["/fake/nvim", "--headless", "+PlugInstall", "+qa"], plan.command
    assert_equal :neovim, @reporter.actions.first[:type]
    assert_predicate plan, :frozen?
  end

  def test_missing_executable_and_configuration_fail_during_planning
    error = assert_raises(Phases::Neovim::Error) { build_phase.prepare }
    assert_equal "Neovim not found; install nvim before running this phase", error.message

    error = assert_raises(Phases::Neovim::Error) do
      build_phase(executables: {"nvim" => "/fake/nvim"}, available_targets: [@targets.first]).prepare
    end
    assert_equal "Neovim configuration is not available: #{@targets.last}", error.message
  end

  def test_apply_uses_the_exact_command_without_redirection_and_surfaces_failures
    [true, false, nil].each do |result|
      @reporter.clear
      runner = TestCommandRunner.new(result: result, executables: {"nvim" => "/fake/nvim"})
      phase = build_phase(command_runner: runner)
      preparation = phase.prepare

      if result
        preparation.apply
        assert_equal :neovim_complete, @reporter.actions.last[:type]
      else
        error = assert_raises(Phases::Neovim::Error) { preparation.apply }
        assert_equal(result.nil? ? "Neovim plugin installation could not start" : "Neovim plugin installation exited with a nonzero status", error.message)
        refute_includes @reporter.action_types, :neovim_complete
      end

      assert_equal [["/fake/nvim", "--headless", "+PlugInstall", "+qa"]], runner.calls
    end
  end

  private

  def build_phase(executables: {}, command_runner: nil, available_targets: @targets)
    runner = command_runner || TestCommandRunner.new(executables: executables)
    Phases::Neovim.new(
      load_configuration_targets: -> { @targets },
      availability: Availability.new(available_targets),
      command_runner: runner,
      reporter: @reporter
    )
  end
end
