# frozen_string_literal: true

require_relative "reporter"

module Reporters
  class NullReporter
    include Reporter

    def report_phase(_name)
    end

    def report_action(_type, _meta = {})
    end

    def report_completion(_steps = [])
    end

    def report_dry_completion
    end

    def report_warning(_message)
    end
  end
end
