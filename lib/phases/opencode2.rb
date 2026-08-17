# frozen_string_literal: true

require "fileutils"
require "json"
require_relative "opencode2/plan"

module Phases
  class OpenCode2
    PACKAGE_SPECIFICATION = "@opencode-ai/cli@next"
    CHANNEL = "next"
    REPOSITORY = "https://github.com/danfrenette/opencode.git"
    BRANCH = "dan-dev"
    MINIMUM_BUN_VERSION = [1, 3].freeze

    class Error < StandardError; end

    def initialize(global_dir:, bin_dir:, checkout:, command_runner:, reporter:)
      @global_dir = global_dir
      @bin_dir = bin_dir
      @checkout = checkout
      @command_runner = command_runner
      @reporter = reporter
    end

    def plan
      reporter.report_phase("Installing OpenCode2")

      package_manager = command_runner.find_executable("pnpm")
      raise Error, "pnpm not found; install pnpm before running the OpenCode2 phase" unless package_manager
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

      validate_destination(global_dir)
      validate_destination(bin_dir)
      validate_checkout

      Plan.new(
        package_manager: package_manager,
        git: git,
        bun: bun,
        bun_version: bun_version,
        package_specification: PACKAGE_SPECIFICATION,
        channel: CHANNEL,
        global_dir: global_dir,
        bin_dir: bin_dir,
        executable: File.join(bin_dir, "opencode2"),
        install_environment: {"PATH" => [bin_dir, ENV.fetch("PATH", "")].reject(&:empty?).join(File::PATH_SEPARATOR)},
        repository: REPOSITORY,
        branch: BRANCH,
        checkout: checkout,
        checkout_exists: File.exist?(checkout)
      ).tap do |phase_plan|
        phase_plan.items.each { |item| reporter.report_action(item.fetch(:type), item.fetch(:meta)) }
      end
    end

    def apply(plan)
      FileUtils.mkdir_p([plan.global_dir, plan.bin_dir])

      result = command_runner.run(*plan.install_command, env: plan.install_environment)
      raise Error, "OpenCode2 installation could not start" if result.nil?
      raise Error, "OpenCode2 installation exited with a nonzero status" unless result

      unless File.file?(plan.executable) && File.executable?(plan.executable)
        raise Error, "OpenCode2 executable was not installed at #{plan.executable}"
      end

      result = command_runner.run(*plan.verification_command)
      raise Error, "OpenCode2 verification could not start" if result.nil?
      raise Error, "OpenCode2 verification exited with a nonzero status" unless result

      FileUtils.mkdir_p(File.dirname(plan.checkout))
      run_required(plan.source_command, "OpenCode fork checkout")
      validate_source_checkout(plan.checkout)
      run_required(plan.dependency_command, "OpenCode fork dependency installation")
    rescue SystemCallError => error
      raise Error, "OpenCode2 filesystem operation failed: #{error.message}"
    end

    private

    attr_reader :global_dir, :bin_dir, :checkout, :command_runner, :reporter

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

      head = File.join(checkout, ".git", "HEAD")
      unless File.file?(head) && File.read(head).strip == "ref: refs/heads/#{BRANCH}"
        raise Error, "OpenCode fork checkout must be on #{BRANCH}: #{checkout}"
      end
      validate_destination(checkout)
    end

    def validate_source_checkout(path)
      manifest = File.join(path, "package.json")
      launcher = File.join(path, "packages", "app", "script", "dev-web-live.ts")
      raise Error, "OpenCode fork package manifest not found: #{manifest}" unless File.file?(manifest)
      raise Error, "OpenCode fork live web launcher not found: #{launcher}" unless File.file?(launcher)

      package = JSON.parse(File.read(manifest))
      scripts = package.is_a?(Hash) ? package["scripts"] : nil
      unless scripts.is_a?(Hash) && scripts.key?("dev:web:live")
        raise Error, "OpenCode fork does not define dev:web:live"
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
  end
end
