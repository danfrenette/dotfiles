# frozen_string_literal: true

require_relative "operation"

module Phases
  class Homebrew
    CANDIDATES = ["/opt/homebrew/bin/brew", "/usr/local/bin/brew"].freeze

    class Error < StandardError; end

    def initialize(brewfile_path:, command_runner:, reporter:)
      @brewfile_path = brewfile_path
      @command_runner = command_runner
      @reporter = reporter
    end

    def plan
      reporter.report_phase("Installing Homebrew packages")

      brew = command_runner.find_executable("brew", candidates: CANDIDATES)
      raise Error, "Homebrew not found; run ./bootstrap.sh first" unless brew

      validate_brewfile

      command = [brew, "bundle", "--file=#{brewfile_path}"]
      operations = [
        Operation.new(type: :available, meta: {path: brew}, command: nil),
        Operation.new(
          type: :bundle,
          meta: {
            command: command,
            brewfile: brewfile_path,
            effect: "install or update declared packages"
          },
          command: command
        )
      ]

      operations.tap do |plan|
        plan.each { |operation| reporter.report_action(operation.type, operation.meta) }
      end
    end

    def apply(plan)
      operation = plan.find { |item| item.type == :bundle }
      result = command_runner.run(*operation.command)
      raise Error, "brew bundle could not start" if result.nil?
      raise Error, "brew bundle exited with a nonzero status" unless result
    end

    private

    attr_reader :brewfile_path, :command_runner, :reporter

    def validate_brewfile
      raise Error, "Brewfile not found: #{brewfile_path}" unless File.exist?(brewfile_path)
      raise Error, "Brewfile is not a regular file: #{brewfile_path}" unless File.file?(brewfile_path)
      raise Error, "Brewfile is not readable: #{brewfile_path}" unless File.readable?(brewfile_path)
    end
  end
end
