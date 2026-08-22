# frozen_string_literal: true

class PreparedPhase
  attr_reader :plan

  def initialize(plan, &application)
    @plan = plan
    @application = application
    freeze
  end

  def apply
    @application.call
  end
end
