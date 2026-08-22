# frozen_string_literal: true

require "test_helper"

class MappingsTest < DotfilesTestCase
  def setup
    super
    @loaded_mappings = []
    load_mappings = -> { @loaded_mappings }
    @phase = Phases::Mappings.new(
      load_mappings: load_mappings,
      availability: Phases::Mappings::ConfigurationAvailability.new(load_mappings: load_mappings),
      reporter: Reporters::TestReporter.new
    )
  end

  def test_relative_link_to_source_is_unchanged
    source = create_file("source/config")
    target = tmp_path("target/config")
    FileUtils.mkdir_p(File.dirname(target))
    File.symlink(File.join("..", "source", "config"), target)

    mapping_plan = prepare([mapping(source, target)]).plan

    assert_equal [:unchanged], mapping_plan.map(&:type)
  end

  private

  def prepare(mappings)
    @loaded_mappings = mappings
    @phase.prepare
  end
end
