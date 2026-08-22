# frozen_string_literal: true

require_relative "homebrew/plan"
require_relative "../prepared_phase"
require_relative "../reporters/console_reporter"
require_relative "error"

module Phases
  class Homebrew
    NAME = :homebrew
    CANDIDATES = ["/opt/homebrew/bin/brew", "/usr/local/bin/brew"].freeze

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

      Plan.new(executable: brew, brewfile: brewfile_path).tap do |plan|
        plan.report
      end
    end

    def apply(plan)
      result = command_runner.run(*plan.command)
      raise Error, "brew bundle could not start" if result.nil?
      raise Error, "brew bundle exited with a nonzero status" unless result
    end

    def validate_brewfile
      raise Error, "Brewfile not found: #{brewfile_path}" unless File.exist?(brewfile_path)
      raise Error, "Brewfile is not a regular file: #{brewfile_path}" unless File.file?(brewfile_path)
      raise Error, "Brewfile is not readable: #{brewfile_path}" unless File.readable?(brewfile_path)
    end
  end
end
