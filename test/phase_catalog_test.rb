# frozen_string_literal: true

require "test_helper"
require "phase_catalog"

class PhaseCatalogTest < DotfilesTestCase
  RecordingPhase = Struct.new(:name, :events) do
    def prepare
      events << [:prepare, name]
      PreparedPhase.new(name) { events << [:apply, name] }
    end
  end

  def test_instance_build_initializes_and_returns_the_catalog
    reporter = Reporters::TestReporter.new
    use_reporter(reporter)
    catalog = PhaseCatalog.new(
      config: TestConfig.new,
      runtime: SetupRuntime.new(reporter: reporter)
    )

    result = catalog.build

    assert_same catalog, result
    assert_equal %i[homebrew opencode2 mappings skills neovim], catalog.names
  end

  def test_setup_workflow_preflights_independent_phases_then_applies_in_catalog_order
    events = []
    reporter = Reporters::TestReporter.new
    use_reporter(reporter)
    phases = %i[homebrew opencode2 mappings skills neovim].map { |name| RecordingPhase.new(name, events) }
    catalog = PhaseCatalog.new(phases, reset_planning: -> { events << :reset })

    workflow = catalog.workflow(:setup)
    preparations = workflow.prepare

    assert_equal [:reset, [:prepare, :homebrew], [:prepare, :mappings]], events

    workflow.apply(preparations)

    assert_equal [
      :reset,
      [:prepare, :homebrew],
      [:prepare, :mappings],
      [:apply, :homebrew],
      [:prepare, :opencode2],
      [:apply, :opencode2],
      [:apply, :mappings],
      [:prepare, :skills],
      [:apply, :skills],
      [:prepare, :neovim],
      [:apply, :neovim]
    ], events
  end

  def test_refresh_contains_only_mappings_and_skills
    events = []
    reporter = Reporters::TestReporter.new
    use_reporter(reporter)
    phases = %i[homebrew opencode2 mappings skills neovim].map { |name| RecordingPhase.new(name, events) }
    workflow = PhaseCatalog.new(phases).workflow(:refresh)

    preparations = workflow.prepare
    workflow.apply(preparations)

    assert_equal [
      [:prepare, :mappings],
      [:prepare, :skills],
      [:apply, :mappings],
      [:apply, :skills]
    ], events
  end

  def test_catalog_rejects_duplicate_names
    phases = [RecordingPhase.new(:homebrew, []), RecordingPhase.new(:homebrew, [])]

    error = assert_raises(ArgumentError) { PhaseCatalog.new(phases, workflows: {}) }

    assert_equal "Duplicate catalog phase: homebrew", error.message
  end

  def test_unknown_workflow_is_rejected
    catalog = PhaseCatalog.new([], workflows: {})

    error = assert_raises(PhaseCatalog::UnsupportedWorkflow) { catalog.workflow(:missing) }

    assert_equal "Unsupported workflow: missing", error.message
  end
end
