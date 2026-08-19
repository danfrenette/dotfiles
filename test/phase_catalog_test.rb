# frozen_string_literal: true

require "test_helper"
require "phase_catalog"

class PhaseCatalogTest < DotfilesTestCase
  Phase = Struct.new(:name)
  RecordingPhase = Struct.new(:name, :events) do
    def prepare
      events << name
      name
    end
  end

  def test_names_and_selection_preserve_catalog_order
    catalog = PhaseCatalog.new([Phase.new(:first), Phase.new(:second), Phase.new(:third)])

    assert_equal [:first, :second, :third], catalog.names
    assert_equal [:first, :third], catalog.phases_for([:third, :first]).map(&:name)
  end

  def test_selection_rejects_an_unsupported_phase
    catalog = PhaseCatalog.new([Phase.new(:first)])

    error = assert_raises(PhaseCatalog::UnsupportedPhase) { catalog.phases_for([:missing]) }

    assert_equal "Unsupported phase: missing", error.message
  end

  def test_catalog_rejects_duplicate_names
    error = assert_raises(ArgumentError) do
      PhaseCatalog.new([Phase.new(:duplicate), Phase.new(:duplicate)])
    end

    assert_equal "Duplicate catalog phase: duplicate", error.message
  end

  def test_prepare_resets_planning_state_before_preparing_in_order
    events = []
    phases = [
      RecordingPhase.new(:first, events),
      RecordingPhase.new(:second, events)
    ]
    catalog = PhaseCatalog.new(phases, reset_planning: -> { events << :reset })

    assert_equal [:first, :second], catalog.prepare(phases)
    assert_equal [:reset, :first, :second], events
  end
end
