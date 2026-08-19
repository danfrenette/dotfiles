# frozen_string_literal: true

require_relative "config"
require_relative "phase_catalog"
require_relative "phases/error"
require_relative "setup_options"
require_relative "setup_runtime"

class Installer
  def self.run(options: SetupOptions.new, config: Config.new, runtime: SetupRuntime.new)
    new(
      options: options,
      prompt: runtime.prompt,
      reporter: runtime.reporter,
      catalog: PhaseCatalog.build(config: config, runtime: runtime)
    ).install
  end

  def initialize(options:, prompt:, reporter:, catalog:)
    @options = options
    @prompt = prompt
    @reporter = reporter
    @catalog = catalog
  end

  def install
    selected = selected_phases
    report_skipped_phases(selected)
    return 0 if selected.empty?

    preparations = catalog.prepare(selected)
    planning_failed = preparations.any?(&:failed?)
    return finish_dry_run(planning_failed) if options.dry_run
    return 0 unless options.yes || prompt.confirm?

    application_failed = preparations.map(&:apply).any?(false)
    reporter.report_completion(["Restart your terminal (or run: exec zsh)"])
    (planning_failed || application_failed) ? 1 : 0
  rescue ArgumentError, Phases::Error, SystemCallError => error
    reporter.report_warning(error.message)
    1
  end

  private

  attr_reader :options, :prompt, :reporter, :catalog

  def selected_phases
    return catalog.phases_for(options.only) if options.only.any?
    return catalog.to_a if options.yes

    catalog.phases_for(prompt.select(catalog.names))
  end

  def report_skipped_phases(selected)
    return if options.only.any?

    (catalog.names - selected.map(&:name)).each do |name|
      reporter.report_action(:skipped, message: "#{name} phase not selected")
    end
  end

  def finish_dry_run(failed)
    reporter.report_dry_completion
    failed ? 1 : 0
  end
end
