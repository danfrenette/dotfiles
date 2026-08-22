# frozen_string_literal: true

require_relative "../../../reporters/console_reporter"

module Phases
  module OpenCode2
    class CLIInstallation
      class Plan
        attr_reader :package_manager,
          :package_specification,
          :channel,
          :global_dir,
          :bin_dir,
          :executable,
          :environment

        def initialize(package_manager:, package_specification:, channel:, global_dir:, bin_dir:, executable:, environment:)
          @package_manager = package_manager
          @package_specification = package_specification
          @channel = channel
          @global_dir = global_dir
          @bin_dir = bin_dir
          @executable = executable
          @environment = environment.freeze
          freeze
        end

        def install_command
          [
            package_manager,
            "add",
            "--global",
            "--global-dir=#{global_dir}",
            "--global-bin-dir=#{bin_dir}",
            package_specification
          ]
        end

        def verification_command
          [executable, "--version"]
        end

        def service_command
          [executable, "service", "start"]
        end

        def report
          reporter = Reporters::ConsoleReporter.current
          reporter.report_planned(:ok, "pnpm executable: #{package_manager}")
          reporter.report_planned(:pkg, "#{package_specification} (prerelease channel: #{channel})")
          reporter.report_planned(
            :dest,
            "#{executable} (packages: #{global_dir}, binaries: #{bin_dir})"
          )
          reporter.report_planned(:run, install_command.join(" "))
          reporter.report_planned(:check, verification_command.join(" "))
        end
      end
    end
  end
end
