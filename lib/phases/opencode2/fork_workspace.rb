# frozen_string_literal: true

require "fileutils"
require "json"
require_relative "error"
require_relative "fork_workspace/plan"

module Phases
  module OpenCode2
    class ForkWorkspace
      REPOSITORY = "https://github.com/danfrenette/opencode.git"
      BRANCH = "dan-dev"
      MINIMUM_BUN_VERSION = [1, 3].freeze
      LIVE_WEB_SCRIPT = "bun run packages/app/script/dev-web-live.ts"
      LIVE_WEB_MARKERS = [
        "OPENCODE_DEV_SERVER_URL",
        'new URL("/api/health", server)',
        "http://127.0.0.1:4096",
        "Start it separately and retry."
      ].freeze

      def initialize(checkout:, command_runner:)
        @checkout = checkout
        @command_runner = command_runner
      end

      def plan
        git = command_runner.find_executable("git", candidates: ["/usr/bin/git"])
        raise Error, "Git not found; install Git before running the OpenCode2 phase" unless git
        bun = command_runner.find_executable("bun")
        raise Error, "Bun not found; install Bun 1.3 or newer before running the OpenCode2 phase" unless bun
        bun_version = command_runner.capture(bun, "--version")&.strip
        unless supported_bun_version?(bun_version)
          message = "Bun 1.3 or newer is required"
          message += "; found #{bun_version}" if bun_version
          raise Error, message
        end

        validate_checkout

        Plan.new(
          git: git,
          bun: bun,
          bun_version: bun_version,
          repository: REPOSITORY,
          branch: BRANCH,
          checkout: checkout,
          checkout_exists: File.exist?(checkout)
        )
      end

      def apply(plan)
        FileUtils.mkdir_p(File.dirname(plan.checkout))
        run_required(plan.source_command, "OpenCode fork checkout")
        validate_source_checkout(plan.checkout)
        run_required(plan.dependency_command, "OpenCode fork dependency installation")
      rescue SystemCallError => error
        raise Error, "OpenCode2 filesystem operation failed: #{error.message}"
      end

      private

      attr_reader :checkout, :command_runner

      def run_required(command, description)
        result = command_runner.run(*command)
        raise Error, "#{description} could not start" if result.nil?
        raise Error, "#{description} exited with a nonzero status" unless result
      end

      def supported_bun_version?(version)
        return false unless version&.match?(/\A\d+\.\d+(?:\.\d+)?\z/)

        parts = version.split(".").map(&:to_i)
        (parts <=> MINIMUM_BUN_VERSION) >= 0
      end

      def validate_checkout
        unless File.exist?(checkout)
          validate_destination(File.dirname(checkout))
          return
        end

        raise Error, "OpenCode fork checkout is not a directory: #{checkout}" unless File.directory?(checkout)

        git_directory = File.join(checkout, ".git")
        unless File.directory?(git_directory)
          raise Error, "OpenCode fork Git metadata is not a directory: #{git_directory}"
        end

        head = File.join(git_directory, "HEAD")
        unless File.file?(head) && File.read(head).strip == "ref: refs/heads/#{BRANCH}"
          raise Error, "OpenCode fork checkout must be on #{BRANCH}: #{checkout}"
        end
        validate_destination(checkout)
        validate_git_metadata(git_directory)
      end

      def validate_source_checkout(path)
        manifest = File.join(path, "package.json")
        launcher = File.join(path, "packages", "app", "script", "dev-web-live.ts")
        raise Error, "OpenCode fork package manifest not found: #{manifest}" unless File.file?(manifest)
        raise Error, "OpenCode fork live web launcher not found: #{launcher}" unless File.file?(launcher)

        package = JSON.parse(File.read(manifest))
        scripts = package.is_a?(Hash) ? package["scripts"] : nil
        unless scripts.is_a?(Hash) && scripts["dev:web:live"] == LIVE_WEB_SCRIPT
          raise Error, "OpenCode fork dev:web:live does not use the expected proxy launcher"
        end

        launcher_source = File.read(launcher)
        unless LIVE_WEB_MARKERS.all? { |marker| launcher_source.include?(marker) }
          raise Error, "OpenCode fork live web launcher does not require the external installed service"
        end
      rescue JSON::ParserError
        raise Error, "OpenCode fork package manifest is invalid: #{manifest}"
      end

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

      def validate_git_metadata(git_directory)
        [git_directory, File.join(git_directory, "objects"), File.join(git_directory, "refs")].each do |path|
          unless File.directory?(path) && File.writable?(path) && File.executable?(path)
            raise Error, "OpenCode fork Git metadata is not writable: #{path}"
          end
        end

        ["HEAD", "index", "FETCH_HEAD"].each do |name|
          path = File.join(git_directory, name)
          next unless File.exist?(path)
          raise Error, "OpenCode fork Git metadata is not writable: #{path}" unless File.file?(path) && File.writable?(path)
        end
      end
    end
  end
end
