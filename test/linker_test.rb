# frozen_string_literal: true

require "test_helper"

class LinkerTest < DotfilesTestCase
  def setup
    super
    @linker = Linker.new
  end

  def test_creates_symlink
    source = create_file("source/myconfig", "config content")
    target = tmp_path("target/myconfig")

    result = @linker.link(source, target)

    assert_equal :linked, result
    assert File.symlink?(target)
    assert_equal source, File.readlink(target)
  end

  def test_creates_parent_directories_for_target
    source = create_file("source/config")
    target = tmp_path("deep/nested/path/config")

    @linker.link(source, target)

    assert File.symlink?(target)
    assert Dir.exist?(tmp_path("deep/nested/path"))
  end

  def test_backs_up_existing_file
    source = create_file("source/config", "new content")
    target = create_file("target/config", "old content")

    @linker.link(source, target)

    assert File.symlink?(target)
    assert File.exist?("#{target}.backup")
    assert_equal "old content", File.read("#{target}.backup")
  end

  def test_backs_up_existing_directory
    source = create_dir("source/nvim")
    create_file("source/nvim/init.vim", "new init")

    target_dir = create_dir("target/nvim")
    create_file("target/nvim/init.vim", "old init")

    @linker.link(source, target_dir)

    assert File.symlink?(target_dir)
    assert Dir.exist?("#{target_dir}.backup")
    assert_equal "old init", File.read("#{target_dir}.backup/init.vim")
  end

  def test_backs_up_existing_broken_symlink
    source = create_file("source/config")
    target = tmp_path("target/config")
    FileUtils.mkdir_p(File.dirname(target))
    File.symlink("/nonexistent/path", target)

    @linker.link(source, target)

    assert File.symlink?(target)
    assert_equal source, File.readlink(target)
    assert File.symlink?("#{target}.backup")
  end

  def test_skips_if_already_correctly_linked
    source = create_file("source/config")
    target = tmp_path("target/config")
    FileUtils.mkdir_p(File.dirname(target))
    File.symlink(source, target)

    result = @linker.link(source, target)

    assert_equal :already_linked, result
    refute File.exist?("#{target}.backup")
  end

  def test_relinks_if_symlink_points_elsewhere
    source = create_file("source/config", "correct")
    wrong_source = create_file("wrong/config", "wrong")
    target = tmp_path("target/config")
    FileUtils.mkdir_p(File.dirname(target))
    File.symlink(wrong_source, target)

    result = @linker.link(source, target)

    assert_equal :linked, result
    assert_equal source, File.readlink(target)
    assert File.symlink?("#{target}.backup")
  end

  def test_raises_if_source_does_not_exist
    target = tmp_path("target/config")

    error = assert_raises(ArgumentError) do
      @linker.link("/nonexistent/source", target)
    end

    assert_match(/Source does not exist/, error.message)
  end

  def test_idempotent_multiple_runs
    source = create_file("source/config")
    target = tmp_path("target/config")

    @linker.link(source, target)
    @linker.link(source, target)
    @linker.link(source, target)

    assert File.symlink?(target)
    assert_equal source, File.readlink(target)
    refute File.exist?("#{target}.backup")
  end

  def test_dry_run_reports_would_link_without_changes
    linker = Linker.new(dry_run: true)
    source = create_file("source/config")
    target = tmp_path("target/config")

    result = linker.link(source, target)

    assert_equal :would_link, result
    refute File.exist?(target)
  end

  def test_dry_run_reports_would_replace_without_changes
    linker = Linker.new(dry_run: true)
    source = create_file("source/config", "new")
    target = create_file("target/config", "old")

    result = linker.link(source, target)

    assert_equal :would_replace, result
    assert_equal "old", File.read(target)
    refute File.exist?("#{target}.backup")
  end

  def test_backup_returns_backup_path
    path = create_file("myfile", "content")

    backup_path = @linker.backup(path)

    assert_equal "#{path}.backup", backup_path
    assert File.exist?(backup_path)
  end

  def test_backup_overwrites_existing_backup
    path = create_file("myfile", "new content")
    create_file("myfile.backup", "old backup")

    @linker.backup(path)

    assert_equal "new content", File.read("#{path}.backup")
  end

  def test_correctly_linked_returns_true_for_correct_symlink
    source = create_file("source")
    target = tmp_path("target")
    File.symlink(source, target)

    assert @linker.correctly_linked?(target, source)
  end

  def test_correctly_linked_returns_false_for_wrong_symlink
    source = create_file("source")
    wrong = create_file("wrong")
    target = tmp_path("target")
    File.symlink(wrong, target)

    refute @linker.correctly_linked?(target, source)
  end

  def test_correctly_linked_returns_false_for_regular_file
    source = create_file("source")
    target = create_file("target")

    refute @linker.correctly_linked?(target, source)
  end

  def test_relative_link_to_source_is_unchanged
    source = create_file("source/config")
    target = tmp_path("target/config")
    FileUtils.mkdir_p(File.dirname(target))
    File.symlink(File.join("..", "source", "config"), target)

    plan = @linker.plan([mapping(source, target)])

    assert_equal [:unchanged], plan.map(&:type)
  end

  def test_copies_file_content_and_mode_idempotently
    source = create_file("source/script", "puts :ok")
    File.chmod(0o751, source)
    target = tmp_path("target/script")
    copy = mapping(source, target, operation: :copy)

    first_plan = @linker.plan([copy])
    @linker.apply(first_plan)
    second_plan = @linker.plan([copy])

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

    @linker.apply(@linker.plan([mapping(source, target, operation: :copy)]))

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

    @linker.apply(@linker.plan([mapping(source, target, operation: :copy)]))

    assert File.symlink?(target)
    assert_equal "missing", File.readlink(target)
  end

  def test_copy_change_plans_backup_removal_before_replacement
    source = create_file("source/config", "new")
    target = create_file("target/config", "old")
    backup = create_file("target/config.backup", "older")

    plan = @linker.plan([mapping(source, target, operation: :copy)])

    assert_equal [:remove, :move, :create_copy], plan.map(&:type)
    assert_equal backup, plan.first.path
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
      @linker.apply(@linker.plan([copy]))

      mutate.call(target)

      assert_includes @linker.plan([copy]).map(&:type), :create_copy, "#{name} change was not detected"
    end
  end

  def test_copy_staging_failure_leaves_all_targets_and_backups_untouched
    first_source = create_file("source/first", "new first")
    second_source = create_file("source/second", "new second")
    first_target = create_file("home/first", "old first")
    first_backup = create_file("home/first.backup", "older first")
    second_target = tmp_path("new-home/nested/second")
    plan = @linker.plan([
      mapping(first_source, first_target, operation: :copy),
      mapping(second_source, second_target, operation: :copy)
    ])
    FileUtils.rm(second_source)

    assert_raises(Errno::ENOENT) { @linker.apply(plan) }

    assert_equal "old first", File.read(first_target)
    assert_equal "older first", File.read(first_backup)
    refute File.exist?(second_target)
    refute Dir.exist?(tmp_path("new-home"))
    assert_empty Dir.glob(File.join(File.dirname(first_target), ".dotfiles-stage-*"))
  end
end
