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
    Reporters::ConsoleReporter.with(reporter) { perform_install }
  end

  private

  attr_reader :options, :prompt, :reporter, :catalog

  def perform_install
    workflow = catalog.workflow(options.workflow)
    preparations = workflow.prepare
    return finish_dry_run if options.dry_run
    return 0 unless options.yes || prompt.confirm?

    workflow.apply(preparations)
    reporter.report_completion(["Restart your terminal (or run: exec zsh)"])
    0
  rescue ArgumentError, Phases::Error, SystemCallError => error
    reporter.report_warning(error.message)
    1
  end

  def finish_dry_run
    reporter.report_dry_completion
    0
  end
end
