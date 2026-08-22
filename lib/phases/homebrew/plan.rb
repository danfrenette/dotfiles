# frozen_string_literal: true

require_relative "../../reporters/console_reporter"

module Phases
  class Homebrew
    class Plan
      attr_reader :executable, :brewfile

      def initialize(executable:, brewfile:)
        @executable = executable
        @brewfile = brewfile
        freeze
      end

      def command
        [executable, "bundle", "--file=#{brewfile}"]
      end

      def report
        reporter = Reporters::ConsoleReporter.current
        reporter.report_planned(:ok, "Homebrew executable: #{executable}")
        reporter.report_planned(:brew, "#{command.join(" ")} (install or update declared packages)")
      end
    end
  end
end
