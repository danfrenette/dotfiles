# frozen_string_literal: true

module Reporters
  module Reporter
    def report_phase(name)
      raise NotImplementedError
    end

    def report_action(type, meta = {})
      raise NotImplementedError
    end

    def report_completion(steps = [])
      raise NotImplementedError
    end

    def report_dry_completion
      raise NotImplementedError
    end

    def report_warning(message)
      raise NotImplementedError
    end
  end
end
