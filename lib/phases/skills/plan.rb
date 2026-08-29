# frozen_string_literal: true

require_relative "../../reporters/console_reporter"

module Phases
  class Skills
    class Plan
      def initialize(package_manager:, catalogs:)
        @package_manager = package_manager
        @catalogs = catalogs
        freeze
      end

      def commands
        catalogs.map { |catalog| catalog.command(package_manager: package_manager) }
      end

      def report
        reporter = Reporters::ConsoleReporter.current
        commands.each do |command|
          reporter.report_planned(:skills, command.join(" "))
        end
      end

      private

      attr_reader :package_manager, :catalogs
    end
  end
end
