# frozen_string_literal: true

require "test_helper"
require "phases/mappings/configuration_availability"

class ConfigurationAvailabilityTest < DotfilesTestCase
  Operation = Struct.new(:target, :establishes_target?)

  def test_targets_returns_current_link_and_copy_mappings_before_planning
    link_source, link_target = create_mapping("linked")
    FileUtils.mkdir_p(File.dirname(link_target))
    File.symlink(link_source, link_target)
    copy_source, copy_target = create_mapping("copied", "same")
    create_file(copy_target, "same")
    mappings = [
      mapping(link_source, link_target),
      mapping(copy_source, copy_target, operation: :copy)
    ]
    availability = described_class.new(load_mappings: -> { mappings })

    assert_equal [link_target, copy_target], availability.targets
  end

  def test_recorded_plan_replaces_current_targets
    current = tmp_path("home/.config/nvim/current.lua")
    source = create_file("dotfiles/nvim/current.lua")
    FileUtils.mkdir_p(File.dirname(current))
    File.symlink(source, current)
    availability = described_class.new(load_mappings: -> { [mapping(source, current)] })
    established = tmp_path("home/.config/nvim/init.lua")
    ignored = tmp_path("home/.config/nvim/ignored.lua")

    availability.record([Operation.new(established, true), Operation.new(ignored, false)])

    assert_equal [established], availability.targets

    availability.reset

    assert_equal [current], availability.targets
  end

  private

  def described_class
    Phases::Mappings::ConfigurationAvailability
  end
end
