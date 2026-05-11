# frozen_string_literal: true

require_relative "reporter"

module Reporters
  class TestReporter
    include Reporter

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

    def report_completion(steps = [])
      @completion_reported = true
      @completion_steps = steps
    end

    def report_dry_completion
      @dry_completion_reported = true
    end

    def report_warning(message)
      warnings << message
    end

    def completion_steps
      @completion_steps || []
    end

    def action_types
      actions.map { |a| a[:type] }
    end

    def action_named(name)
      actions.find { |a| a[:meta][:name] == name }
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
