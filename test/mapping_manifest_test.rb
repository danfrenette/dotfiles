# frozen_string_literal: true

require "test_helper"

class MappingManifestTest < DotfilesTestCase
  def setup
    super
    @repository_root = create_dir("repository")
    @home_root = create_dir("home")
  end

  def test_rejects_invalid_top_level_shapes
    ["", "mappings: {}", "other: []", "mappings: []\nextra: true"].each do |yaml|
      assert_invalid(yaml, /mappings array/)
    end
  end

  def test_rejects_invalid_entry_shapes
    assert_invalid("mappings:\n  - source: file\n    target: .file", /exactly operation, source, and target strings/)
    assert_invalid(<<~YAML, /exactly operation, source, and target strings/)
      mappings:
        - operation: link
          source: file
          target: .file
          extra: true
    YAML
    assert_invalid("mappings:\n  - operation: link\n    source: 1\n    target: .file", /exactly operation/)
  end

  def test_rejects_unsupported_operations
    assert_invalid(manifest(operation: "move"), /unsupported operation/)
  end

  def test_rejects_invalid_source_and_target_paths
    ["", ".", "..", "~/.file", "/absolute", "nested/../escape", "nested//file"].each do |path|
      assert_invalid(manifest(source: path), /source must be a non-empty relative path/)
      assert_invalid(manifest(target: path), /target must be a non-empty relative path/)
    end
  end

  def test_rejects_duplicate_and_overlapping_targets_on_path_boundaries
    create_file("repository/first")
    create_file("repository/second")

    assert_invalid(two_entry_manifest("config", "config"), /targets overlap/)
    assert_invalid(two_entry_manifest("config", "config/nested"), /targets overlap/)

    mappings = load_manifest(two_entry_manifest("config", "configuration"))
    assert_equal ["config", "configuration"], mappings.map { |mapping| File.basename(mapping.target) }
  end

  def test_rejects_target_parent_symlink_that_escapes_home
    create_file("repository/file")
    outside = create_dir("outside")
    File.symlink(outside, File.join(@home_root, "escaped"))

    assert_invalid(manifest(target: "escaped/file"), /escapes home root/)
  end

  def test_reports_all_missing_sources
    error = assert_raises(MappingManifest::InvalidManifest) do
      load_manifest(<<~YAML)
        mappings:
          - operation: link
            source: first-missing
            target: .first
          - operation: copy
            source: second-missing
            target: .second
      YAML
    end

    assert_includes error.message, File.join(@repository_root, "first-missing")
    assert_includes error.message, File.join(@repository_root, "second-missing")
  end

  def test_copy_accepts_a_broken_root_symlink_but_link_rejects_it
    File.symlink("missing", File.join(@repository_root, "broken"))

    assert_equal :copy, load_manifest(manifest(operation: "copy", source: "broken")).first.operation
    assert_invalid(manifest(operation: "link", source: "broken"), /sources do not exist/)
  end

  private

  def manifest(operation: "link", source: "file", target: ".file")
    <<~YAML
      mappings:
        - operation: #{operation.inspect}
          source: #{source.inspect}
          target: #{target.inspect}
    YAML
  end

  def two_entry_manifest(first_target, second_target)
    <<~YAML
      mappings:
        - operation: link
          source: first
          target: #{first_target}
        - operation: copy
          source: second
          target: #{second_target}
    YAML
  end

  def load_manifest(yaml)
    path = create_file("manifest-#{rand(1_000_000)}.yml", yaml)
    MappingManifest.load(path, repository_root: @repository_root, home_root: @home_root)
  end

  def assert_invalid(yaml, message)
    error = assert_raises(MappingManifest::InvalidManifest) { load_manifest(yaml) }
    assert_match message, error.message
  end
end
