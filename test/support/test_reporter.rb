# frozen_string_literal: true

module Reporters
  class TestReporter
    attr_reader :phases, :actions, :warnings, :completion_reported, :dry_completion_reported

    def initialize
      @phases = []
      @actions = []
      @warnings = []
      @completion_reported = false
      @dry_completion_reported = false
    end

    def report_phase(name)
      phases << name
    end

    def report_action(type, meta = {})
      actions << {type: type, meta: meta}
    end

    def report_completion(_steps = [])
      @completion_reported = true
    end

    def report_dry_completion
      @dry_completion_reported = true
    end

    def report_warning(message)
      warnings << message
    end

    def action_types
      actions.map { |a| a[:type] }
    end

    def clear
      phases.clear
      actions.clear
      warnings.clear
      @completion_reported = false
      @dry_completion_reported = false
    end
  end
end
