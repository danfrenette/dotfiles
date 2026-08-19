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

  def test_copies_file_content_and_mode_idempotently
    source = create_file("source/script", "puts :ok")
    File.chmod(0o751, source)
    target = tmp_path("target/script")
    copy = mapping(source, target, operation: :copy)

    first_preparation = prepare([copy])
    first_preparation.apply
    second_plan = prepare([copy]).plan

    assert_equal "puts :ok", File.read(target)
    assert_equal 0o751, File.stat(target).mode & 0o777
    assert_equal [:unchanged_copy], second_plan.map(&:type)
    refute File.exist?("#{target}.backup")
  end

  def test_recursively_copies_modes_and_symlinks_without_dereferencing
    source = create_dir("source/tree")
    nested = create_dir("source/tree/nested")
    file = create_file("source/tree/nested/file", "content")
    File.chmod(0o750, nested)
    File.chmod(0o640, file)
    File.symlink("file", File.join(nested, "link"))
    File.symlink("missing", File.join(nested, "broken"))
    target = tmp_path("target/tree")

    prepare([mapping(source, target, operation: :copy)]).apply

    assert_equal 0o750, File.stat(File.join(target, "nested")).mode & 0o777
    assert_equal 0o640, File.stat(File.join(target, "nested", "file")).mode & 0o777
    assert_equal "file", File.readlink(File.join(target, "nested", "link"))
    assert_equal "missing", File.readlink(File.join(target, "nested", "broken"))
  end

  def test_copies_root_symlink_without_dereferencing
    source = tmp_path("source/root-link")
    FileUtils.mkdir_p(File.dirname(source))
    File.symlink("missing", source)
    target = tmp_path("target/root-link")

    prepare([mapping(source, target, operation: :copy)]).apply

    assert File.symlink?(target)
    assert_equal "missing", File.readlink(target)
  end

  def test_copy_change_plans_backup_removal_before_replacement
    source = create_file("source/config", "new")
    target = create_file("target/config", "old")
    backup = create_file("target/config.backup", "older")

    mapping_plan = prepare([mapping(source, target, operation: :copy)]).plan

    assert_equal [:remove, :move, :create_copy], mapping_plan.map(&:type)
    assert_equal backup, mapping_plan.first.path
  end

  def test_copy_detects_content_mode_type_entry_and_symlink_text_changes
    scenarios = {
      content: ->(target) { File.write(File.join(target, "file"), "changed") },
      mode: ->(target) { File.chmod(0o600, File.join(target, "file")) },
      type: ->(target) do
        FileUtils.rm(File.join(target, "file"))
        FileUtils.mkdir(File.join(target, "file"))
      end,
      entry: ->(target) { File.write(File.join(target, "extra"), "extra") },
      symlink_text: ->(target) do
        FileUtils.rm(File.join(target, "link"))
        File.symlink("other", File.join(target, "link"))
      end
    }

    scenarios.each do |name, mutate|
      source = create_dir("source/#{name}")
      file = create_file("source/#{name}/file", "original")
      File.chmod(0o640, file)
      File.symlink("file", File.join(source, "link"))
      target = tmp_path("target/#{name}")
      copy = mapping(source, target, operation: :copy)
      prepare([copy]).apply

      mutate.call(target)

      assert_includes prepare([copy]).plan.map(&:type), :create_copy, "#{name} change was not detected"
    end
  end

  def test_copy_staging_failure_leaves_all_targets_and_backups_untouched
    first_source = create_file("source/first", "new first")
    second_source = create_file("source/second", "new second")
    first_target = create_file("home/first", "old first")
    first_backup = create_file("home/first.backup", "older first")
    second_target = tmp_path("new-home/nested/second")
    preparation = prepare([
      mapping(first_source, first_target, operation: :copy),
      mapping(second_source, second_target, operation: :copy)
    ])
    FileUtils.rm(second_source)

    assert_raises(Errno::ENOENT) { preparation.apply }

    assert_equal "old first", File.read(first_target)
    assert_equal "older first", File.read(first_backup)
    refute File.exist?(second_target)
    refute Dir.exist?(tmp_path("new-home"))
    assert_empty Dir.glob(File.join(File.dirname(first_target), ".dotfiles-stage-*"))
  end

  private

  def prepare(mappings)
    @loaded_mappings = mappings
    @phase.prepare
  end
end
