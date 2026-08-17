# frozen_string_literal: true

module Phases
  class OpenCode2
    Plan = Data.define(
      :package_manager,
      :git,
      :bun,
      :bun_version,
      :package_specification,
      :channel,
      :global_dir,
      :bin_dir,
      :executable,
      :install_environment,
      :repository,
      :branch,
      :checkout,
      :checkout_exists
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

      def source_command
        if checkout_exists
          [git, "-C", checkout, "pull", "--ff-only", repository, branch]
        else
          [git, "clone", "--branch", branch, "--single-branch", repository, checkout]
        end
      end

      def dependency_command
        [bun, "install", "--frozen-lockfile", "--cwd", checkout]
      end

      def launch_command
        [bun, "run", "--cwd", checkout, "dev:web:live"]
      end

      def items
        [
          {type: :package_manager, meta: {name: "pnpm", path: package_manager}},
          {type: :package, meta: {specification: package_specification, channel: channel}},
          {
            type: :destination,
            meta: {package_directory: global_dir, binary_directory: bin_dir, executable: executable}
          },
          {type: :install, meta: {command: install_command, environment: install_environment}},
          {type: :verify, meta: {command: verification_command}},
          {
            type: :source,
            meta: {repository: repository, branch: branch, checkout: checkout, command: source_command}
          },
          {type: :dependencies, meta: {runtime: bun, version: bun_version, command: dependency_command}},
          {
            type: :workflow,
            meta: {
              name: "dev:web:live",
              command: launch_command,
              effect: "proxy to the installed opencode2 service and shared sessions"
            }
          }
        ]
      end
    end
  end
end
