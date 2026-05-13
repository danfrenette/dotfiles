# frozen_string_literal: true

require "fileutils"
require_relative "linker"
require_relative "reporters/console_reporter"

class SkillInstaller
  def initialize(dry_run: false, linker: nil, reporter: nil)
    @dry_run = dry_run
    @linker = linker || Linker.new(dry_run: dry_run)
    @reporter = reporter || Reporters::ConsoleReporter.new
  end

  def install(skills, target_dir:)
    if skills.empty?
      reporter.report_warning("no skills to install")
      return
    end

    skills.each do |name, source|
      target = File.join(target_dir, name)
      result = linker.link(source, target)
      reporter.report_action(result, name: name, source: source, target: target)
    end
  end

  private

  attr_reader :linker, :reporter
end
