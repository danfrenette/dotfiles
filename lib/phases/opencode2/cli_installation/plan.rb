# frozen_string_literal: true

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

        def items
          [
            {type: :package_manager, meta: {name: "pnpm", path: package_manager}},
            {type: :package, meta: {specification: package_specification, channel: channel}},
            {
              type: :destination,
              meta: {package_directory: global_dir, binary_directory: bin_dir, executable: executable}
            },
            {type: :install, meta: {command: install_command, environment: environment}},
            {type: :verify, meta: {command: verification_command}}
          ]
        end
      end
    end
  end
end
