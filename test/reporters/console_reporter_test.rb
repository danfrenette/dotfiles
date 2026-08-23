# frozen_string_literal: true

require "test_helper"

class ConsoleReporterTest < DotfilesTestCase
  TtyOutput = Class.new(StringIO) do
    def tty?
      true
    end
  end

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

  def test_colors_interactive_output
    output = TtyOutput.new

    Reporters::ConsoleReporter.new(output: output).report_completion

    assert_includes output.string, "\e[32mInstallation complete!\e[0m"
  end

  def test_leaves_non_interactive_output_uncolored
    output = StringIO.new

    Reporters::ConsoleReporter.new(output: output).report_completion

    refute_includes output.string, "\e["
  end

  def test_indents_multiline_warnings
    output = StringIO.new

    Reporters::ConsoleReporter.new(output: output).report_warning("Update required\nRun: open settings")

    assert_equal "  [SKIP] Update required\n         Run: open settings\n", output.string
  end
end
