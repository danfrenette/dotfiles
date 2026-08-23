# frozen_string_literal: true

require_relative "../../reporters/console_reporter"

module Phases
  class Homebrew
    class Plan
      attr_reader :executable, :brewfile, :trusted_formulae

      def initialize(executable:, brewfile:, trusted_formulae:)
        @executable = executable
        @brewfile = brewfile
        @trusted_formulae = trusted_formulae.freeze
        freeze
      end

      def trust_commands
        trusted_formulae.map { |formula| [executable, "trust", "--formula", formula] }
      end

      def bundle_command
        [executable, "bundle", "--file=#{brewfile}"]
      end

      def report
        reporter = Reporters::ConsoleReporter.current
        reporter.report_planned(:ok, "Homebrew executable: #{executable}")
        trust_commands.each { |command| reporter.report_planned(:trust, command.join(" ")) }
        reporter.report_planned(:sudo, "sudo -v (authenticate once for privileged casks)")
        reporter.report_planned(:brew, "#{bundle_command.join(" ")} (install or update declared packages)")
      end
    end
  end
end
