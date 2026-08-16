# frozen_string_literal: true

require_relative "homebrew/plan"

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

      Plan.new(executable: brew, brewfile: brewfile_path).tap do |plan|
        plan.items.each { |item| reporter.report_action(item.fetch(:type), item.fetch(:meta)) }
      end
    end

    def apply(plan)
      result = command_runner.run(*plan.command)
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
