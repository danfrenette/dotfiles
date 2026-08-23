# frozen_string_literal: true

require_relative "homebrew/plan"
require_relative "../prepared_phase"
require_relative "../reporters/console_reporter"
require_relative "error"

module Phases
  class Homebrew
    NAME = :homebrew
    CANDIDATES = ["/opt/homebrew/bin/brew", "/usr/local/bin/brew"].freeze
    TRUSTED_FORMULAE = ["oven-sh/bun/bun"].freeze
    DEVELOPER_TOOL_CHECKS = %w[check_clt_minimum_version check_xcode_minimum_version].freeze

    class Error < Phases::Error; end

    def initialize(brewfile_path:, command_runner:)
      @brewfile_path = brewfile_path
      @command_runner = command_runner
    end

    def name
      NAME
    end

    def prepare
      plan = build_plan
      PreparedPhase.new(plan) { apply(plan) }
    end

    private

    attr_reader :brewfile_path, :command_runner

    def build_plan
      Reporters::ConsoleReporter.current.report_phase("Installing Homebrew packages")

      brew = command_runner.find_executable("brew", candidates: CANDIDATES)
      raise Error, "Homebrew not found; run ./bootstrap.sh first" unless brew

      validate_brewfile
      validate_developer_tools(brew)

      Plan.new(executable: brew, brewfile: brewfile_path, trusted_formulae: TRUSTED_FORMULAE).tap do |plan|
        Reporters::ConsoleReporter.current.report_planned(:ok, "Apple developer tools meet Homebrew requirements")
        plan.report
      end
    end

    def apply(plan)
      plan.trust_commands.each do |command|
        result = command_runner.run(*command)
        raise Error, "brew trust could not start" if result.nil?
        raise Error, "brew trust exited with a nonzero status" unless result
      end

      result = command_runner.run("sudo", "-v")
      raise Error, "sudo authentication could not start" if result.nil?
      raise Error, "sudo authentication failed" unless result

      result = command_runner.run(*plan.bundle_command)
      raise Error, "brew bundle could not start" if result.nil?
      raise Error, "brew bundle exited with a nonzero status" unless result
    end

    def validate_brewfile
      raise Error, "Brewfile not found: #{brewfile_path}" unless File.exist?(brewfile_path)
      raise Error, "Brewfile is not a regular file: #{brewfile_path}" unless File.file?(brewfile_path)
      raise Error, "Brewfile is not readable: #{brewfile_path}" unless File.readable?(brewfile_path)
    end

    def validate_developer_tools(brew)
      validate_xcode_license
      return if DEVELOPER_TOOL_CHECKS.all? { |check| command_runner.capture(brew, "doctor", check) }

      raise Error,
        "Apple developer tools are missing or outdated.\n" \
        "Open Software Update:\n" \
        "  open 'x-apple.systempreferences:com.apple.Software-Update-Settings.extension'\n" \
        "Update Xcode too if installed:\n" \
        "  open 'macappstore://itunes.apple.com/app/id497799835'\n" \
        "Then rerun: dotfiles setup"
    end

    def validate_xcode_license
      developer_directory = command_runner.capture("xcode-select", "-p")
      return unless developer_directory&.include?("Xcode.app")
      return if command_runner.capture("xcodebuild", "-license", "check")

      raise Error,
        "Xcode license has not been accepted.\n" \
        "Run:\n" \
        "  sudo xcodebuild -license accept\n" \
        "Then rerun: dotfiles setup"
    end
  end
end
