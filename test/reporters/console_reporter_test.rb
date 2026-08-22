# frozen_string_literal: true

require "test_helper"

class ConsoleReporterTest < DotfilesTestCase
  def test_with_scopes_and_restores_the_current_reporter
    original = Reporters::ConsoleReporter.current
    replacement = Reporters::TestReporter.new

    assert_raises(RuntimeError) do
      Reporters::ConsoleReporter.with(replacement) do
        assert_same replacement, Reporters::ConsoleReporter.current
        raise "stop"
      end
    end

    assert_same original, Reporters::ConsoleReporter.current
  end
end
