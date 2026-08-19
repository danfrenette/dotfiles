# frozen_string_literal: true

require "test_helper"
require "installer"
require "reporters/test_reporter"

class InstallerWorkflowTest < DotfilesTestCase
  class Phase
    def initialize(name, events)
      @name = name
      @events = events
    end

    def plan(**)
      events << [:plan, name]
      name
    end

    def apply(plan)
      raise "wrong plan for #{name}" unless plan == name

      events << [:apply, name]
    end

    def current_targets
      [:current]
    end

    def established_targets(plan)
      raise "wrong mappings plan" unless plan == :mappings

      [:planned]
    end

    private

    attr_reader :name, :events
  end

  def test_every_phase_subset_plans_then_applies_only_selected_phases_in_canonical_order
    phases = SetupOptions::SUPPORTED_PHASES

    1.upto(phases.length) do |size|
      phases.combination(size).each do |selected|
        events = []
        status = build_installer(selected, events, yes: true).install
        expected = selected.map { |phase| [:plan, phase] } + selected.map { |phase| [:apply, phase] }

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
    assert_equal [[:plan, :mappings], [:plan, :skills], [:apply, :mappings], [:apply, :skills]], events
    assert_equal 1, prompt.confirmations
  end

  def test_selection_order_does_not_change_canonical_execution_order
    events = []

    status = build_installer([:neovim, :mappings], events, yes: true).install

    assert_equal 0, status
    assert_equal [[:plan, :mappings], [:plan, :neovim], [:apply, :mappings], [:apply, :neovim]], events
  end

  private

  def build_installer(selected, events, yes: false, prompt: TestPrompt.new)
    phase_modules = SetupOptions::SUPPORTED_PHASES.to_h { |name| [name, Phase.new(name, events)] }

    Installer.new(
      options: SetupOptions.new(only: selected, yes: yes),
      prompt: prompt,
      reporter: Reporters::TestReporter.new,
      **phase_modules
    )
  end
end
