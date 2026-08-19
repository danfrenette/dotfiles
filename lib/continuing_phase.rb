# frozen_string_literal: true

require_relative "prepared_phase"

class ContinuingPhase
  def initialize(phase:, reporter:, planning_errors:, application_errors:)
    @phase = phase
    @reporter = reporter
    @planning_errors = planning_errors.freeze
    @application_errors = application_errors.freeze
  end

  def name
    phase.name
  end

  def prepare
    ContinuingPreparation.new(
      preparation: phase.prepare,
      reporter: reporter,
      errors: application_errors
    )
  rescue *planning_errors => error
    reporter.report_warning(error.message)
    PreparedPhase.failure
  end

  private

  attr_reader :phase, :reporter, :planning_errors, :application_errors

  class ContinuingPreparation
    attr_reader :plan

    def initialize(preparation:, reporter:, errors:)
      @preparation = preparation
      @plan = preparation.plan
      @reporter = reporter
      @errors = errors
      freeze
    end

    def failed?
      preparation.failed?
    end

    def apply
      preparation.apply
    rescue *errors => error
      reporter.report_warning(error.message)
      false
    end

    private

    attr_reader :preparation, :reporter, :errors
  end
end
