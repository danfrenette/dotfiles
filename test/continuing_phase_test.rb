# frozen_string_literal: true

require "test_helper"
require "continuing_phase"

class ContinuingPhaseTest < DotfilesTestCase
  PlanningError = Class.new(StandardError)
  ApplicationError = Class.new(StandardError)

  class Phase
    attr_reader :name

    def initialize(planning_error: nil, application_error: nil)
      @name = :recoverable
      @planning_error = planning_error
      @application_error = application_error
    end

    def prepare
      raise planning_error if planning_error

      PreparedPhase.new(:plan) { raise application_error if application_error }
    end

    private

    attr_reader :planning_error, :application_error
  end

  def setup
    super
    @reporter = Reporters::TestReporter.new
  end

  def test_planning_failure_returns_failed_preparation
    phase = build_phase(planning_error: PlanningError.new("planning failed"))

    preparation = phase.prepare

    assert_predicate preparation, :failed?
    refute preparation.apply
    assert_equal ["planning failed"], @reporter.warnings
  end

  def test_application_failure_returns_false
    phase = build_phase(application_error: ApplicationError.new("application failed"))

    preparation = phase.prepare

    refute_predicate preparation, :failed?
    refute preparation.apply
    assert_equal ["application failed"], @reporter.warnings
  end

  def test_unconfigured_failure_escapes
    phase = build_phase(planning_error: RuntimeError.new("unexpected"))

    assert_raises(RuntimeError) { phase.prepare }
    assert_empty @reporter.warnings
  end

  private

  def build_phase(**options)
    ContinuingPhase.new(
      phase: Phase.new(**options),
      reporter: @reporter,
      planning_errors: [PlanningError],
      application_errors: [ApplicationError]
    )
  end
end
