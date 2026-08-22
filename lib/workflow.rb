# frozen_string_literal: true

class Workflow
  attr_reader :name

  def initialize(name:, phases:, preflight:, descriptions:, reporter:)
    @name = name
    @phases = phases.freeze
    @preflight = preflight.freeze
    @descriptions = descriptions
    @reporter = reporter
  end

  def prepare
    reporter.report_workflow(name, phases.map { |phase| [phase.name, descriptions.fetch(phase.name, phase.name.to_s)] })
    phases.to_h do |phase|
      [phase.name, preflight.include?(phase.name) ? phase.prepare : nil]
    end
  end

  def apply(preparations)
    phases.each do |phase|
      preparation = preparations.fetch(phase.name) || phase.prepare
      preparation.apply
    end
  end

  private

  attr_reader :phases, :preflight, :descriptions, :reporter
end
