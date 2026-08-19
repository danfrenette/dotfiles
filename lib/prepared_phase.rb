# frozen_string_literal: true

class PreparedPhase
  attr_reader :plan

  def self.failure
    new(nil, failed: true) {}
  end

  def initialize(plan, failed: false, &application)
    @plan = plan
    @failed = failed
    @application = application
    freeze
  end

  def failed?
    @failed
  end

  def apply
    return false if failed?

    @application.call
    true
  end
end
