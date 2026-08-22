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
    assert_invalid("mappings:\n  - source: file", /exactly source and target strings/)
    assert_invalid(<<~YAML, /exactly source and target strings/)
      mappings:
        - source: file
          target: .file
          extra: true
    YAML
    assert_invalid("mappings:\n  - source: 1\n    target: .file", /exactly source/)
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

  def test_rejects_source_with_symlinked_ancestor_that_escapes_repository
    outside = create_dir("outside")
    create_file("outside/secret")
    File.symlink(outside, File.join(@repository_root, "escaped"))

    assert_invalid(manifest(source: "escaped/secret"), /source parent escapes repository root/)
  end

  def test_rejects_targets_that_collide_with_generated_backup_paths
    create_file("repository/first")
    create_file("repository/second")

    assert_invalid(two_entry_manifest("x", "x.backup"), /backup path overlaps mapping target/)
    assert_invalid(two_entry_manifest("x", "x.backup/nested"), /backup path overlaps mapping target/)
  end

  def test_reports_all_missing_sources
    error = assert_raises(MappingManifest::InvalidManifest) do
      load_manifest(<<~YAML)
        mappings:
          - source: first-missing
            target: .first
          - source: second-missing
            target: .second
      YAML
    end

    assert_includes error.message, File.join(@repository_root, "first-missing")
    assert_includes error.message, File.join(@repository_root, "second-missing")
  end

  private

  def manifest(source: "file", target: ".file")
    <<~YAML
      mappings:
        - source: #{source.inspect}
          target: #{target.inspect}
    YAML
  end

  def two_entry_manifest(first_target, second_target)
    <<~YAML
      mappings:
        - source: first
          target: #{first_target}
        - source: second
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
