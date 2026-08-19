# frozen_string_literal: true

require "test_helper"
require "installer"

class InstallerWorkflowTest < DotfilesTestCase
  class Phase
    attr_reader :name

    def initialize(name, events)
      @name = name
      @events = events
    end

    def prepare
      events << [:prepare, name]
      PreparedPhase.new(name) { events << [:apply, name] }
    end

    private

    attr_reader :events
  end

  def test_every_phase_subset_plans_then_applies_only_selected_phases_in_canonical_order
    phases = catalog([]).names

    1.upto(phases.length) do |size|
      phases.combination(size).each do |selected|
        events = []
        status = build_installer(selected, events, yes: true).install
        expected = selected.map { |phase| [:prepare, phase] } + selected.map { |phase| [:apply, phase] }

        assert_equal 0, status, "status for #{selected.inspect}"
        assert_equal expected, events, "events for #{selected.inspect}"
      end
    end
  end

  def test_selected_phases_share_one_confirmation
    events = []
    prompt = TestPrompt.new(true)

    status = build_installer([:mappings, :skills], events, prompt: prompt).install

    assert_equal 0, status
    assert_equal [[:prepare, :mappings], [:prepare, :skills], [:apply, :mappings], [:apply, :skills]], events
    assert_equal 1, prompt.confirmations
  end

  def test_selection_order_does_not_change_canonical_execution_order
    events = []

    status = build_installer([:neovim, :mappings], events, yes: true).install

    assert_equal 0, status
    assert_equal [[:prepare, :mappings], [:prepare, :neovim], [:apply, :mappings], [:apply, :neovim]], events
  end

  private

  def build_installer(selected, events, yes: false, prompt: TestPrompt.new)
    Installer.new(
      options: SetupOptions.new(only: selected, yes: yes),
      prompt: prompt,
      reporter: Reporters::TestReporter.new,
      catalog: catalog(events)
    )
  end

  def catalog(events)
    PhaseCatalog.new([:homebrew, :opencode2, :mappings, :skills, :neovim].map do |name|
      Phase.new(name, events)
    end)
  end
end
