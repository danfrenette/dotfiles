# frozen_string_literal: true

require "test_helper"
require "installer"

class InstallerWorkflowTest < DotfilesTestCase
  Phase = Struct.new(:name, :events) do
    def prepare
      events << [:prepare, name]
      PreparedPhase.new(name) { events << [:apply, name] }
    end
  end

  def test_setup_establishes_prerequisites_before_preparing_dependent_phases
    events = []

    status = build_installer(:setup, events, yes: true).install

    assert_equal 0, status
    assert_operator events.index([:apply, :homebrew]), :<, events.index([:prepare, :opencode2])
    assert_operator events.index([:apply, :mappings]), :<, events.index([:prepare, :neovim])
  end

  def test_refresh_preflights_then_applies_mappings_and_skills
    events = []

    status = build_installer(:refresh, events, yes: true).install

    assert_equal 0, status
    assert_equal [
      [:prepare, :mappings],
      [:prepare, :skills],
      [:apply, :mappings],
      [:apply, :skills]
    ], events
  end

  def test_workflow_uses_one_confirmation
    events = []
    prompt = TestPrompt.new(true)

    status = build_installer(:refresh, events, prompt: prompt).install

    assert_equal 0, status
    assert_equal 1, prompt.confirmations
  end

  def test_failure_stops_setup_and_reports_no_completion
    events = []
    reporter = Reporters::TestReporter.new
    phases = standard_phases(events)
    failing = phases.find { |phase| phase.name == :opencode2 }
    def failing.prepare
      raise Phases::Error, "OpenCode2 failed"
    end
    catalog = PhaseCatalog.new(phases)
    installer = Installer.new(
      options: SetupOptions.new(workflow: :setup, yes: true),
      prompt: TestPrompt.new,
      reporter: reporter,
      catalog: catalog
    )

    status = installer.install

    assert_equal 1, status
    assert_includes reporter.warnings, "OpenCode2 failed"
    refute reporter.completion_reported
    refute_includes events, [:apply, :mappings]
  end

  private

  def build_installer(workflow, events, yes: false, prompt: TestPrompt.new)
    reporter = Reporters::TestReporter.new
    Installer.new(
      options: SetupOptions.new(workflow: workflow, yes: yes),
      prompt: prompt,
      reporter: reporter,
      catalog: PhaseCatalog.new(standard_phases(events))
    )
  end

  def standard_phases(events)
    %i[homebrew opencode2 mappings skills neovim].map { |name| Phase.new(name, events) }
  end
end
