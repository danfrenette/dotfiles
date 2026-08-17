# frozen_string_literal: true

require "fileutils"
require_relative "error"

module Phases
  module OpenCode2
    class CLIInstallation
      PACKAGE_SPECIFICATION = "@opencode-ai/cli@next"
      CHANNEL = "next"

      Plan = Data.define(
        :package_manager,
        :package_specification,
        :channel,
        :global_dir,
        :bin_dir,
        :executable,
        :environment
      ) do
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

      def initialize(global_dir:, bin_dir:, package_manager_candidates:, command_runner:)
        @global_dir = global_dir
        @bin_dir = bin_dir
        @package_manager_candidates = package_manager_candidates
        @command_runner = command_runner
      end

      def plan
        package_manager = command_runner.find_executable(
          "pnpm",
          candidates: package_manager_candidates,
          search_path: false
        )
        raise Error, "pnpm not found; install pnpm before running the OpenCode2 phase" unless package_manager

        validate_destination(global_dir)
        validate_destination(bin_dir)

        Plan.new(
          package_manager: package_manager,
          package_specification: PACKAGE_SPECIFICATION,
          channel: CHANNEL,
          global_dir: global_dir,
          bin_dir: bin_dir,
          executable: File.join(bin_dir, "opencode2"),
          environment: {"PATH" => [bin_dir, ENV.fetch("PATH", "")].reject(&:empty?).join(File::PATH_SEPARATOR)}
        )
      end

      def apply(plan)
        FileUtils.mkdir_p([plan.global_dir, plan.bin_dir])

        result = command_runner.run(*plan.install_command, env: plan.environment)
        raise Error, "OpenCode2 installation could not start" if result.nil?
        raise Error, "OpenCode2 installation exited with a nonzero status" unless result

        unless File.file?(plan.executable) && File.executable?(plan.executable)
          raise Error, "OpenCode2 executable was not installed at #{plan.executable}"
        end

        result = command_runner.run(*plan.verification_command)
        raise Error, "OpenCode2 verification could not start" if result.nil?
        raise Error, "OpenCode2 verification exited with a nonzero status" unless result
      rescue SystemCallError => error
        raise Error, "OpenCode2 filesystem operation failed: #{error.message}"
      end

      private

      attr_reader :global_dir, :bin_dir, :package_manager_candidates, :command_runner

      def validate_destination(path)
        ancestor = path
        ancestor = File.dirname(ancestor) until File.exist?(ancestor)

        unless File.directory?(ancestor)
          raise Error, "OpenCode2 destination has a non-directory component: #{ancestor}"
        end
        unless File.writable?(ancestor) && File.executable?(ancestor)
          raise Error, "OpenCode2 destination is not writable: #{path}"
        end
      end
    end
  end
end
