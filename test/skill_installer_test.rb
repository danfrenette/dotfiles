# frozen_string_literal: true

require "test_helper"
require "skill_installer"
require "reporters/test_reporter"

class SkillInstallerTest < DotfilesTestCase
  def setup
    super
    @reporter = Reporters::TestReporter.new
    @linker = Linker.new
    @target_dir = tmp_path("target/skills")
  end

  def test_links_each_skill
    source = create_dir("source/tdd")
    skills = {"tdd" => source}

    installer.install(skills, target_dir: @target_dir)

    target = File.join(@target_dir, "tdd")
    assert_symlink target, to: source
  end

  def test_skips_already_linked_skill
    source = create_dir("source/tdd")
    FileUtils.mkdir_p(@target_dir)
    target = File.join(@target_dir, "tdd")
    File.symlink(source, target)
    skills = {"tdd" => source}

    installer.install(skills, target_dir: @target_dir)

    assert_reported_action @reporter, :already_linked, name: "tdd"
  end

  def test_backs_up_existing_target_directory
    source = create_dir("source/tdd")
    target = create_dir(File.join(@target_dir, "tdd"))
    create_file(File.join(target, "old.md"), "old")
    skills = {"tdd" => source}

    installer.install(skills, target_dir: @target_dir)

    assert_symlink target, to: source
    assert File.exist?("#{target}.backup/old.md")
  end

  def test_dry_run_does_not_link_skill
    source = create_dir("source/tdd")
    skills = {"tdd" => source}
    dry_linker = Linker.new(dry_run: true)
    dry_installer = SkillInstaller.new(linker: dry_linker, reporter: @reporter)

    dry_installer.install(skills, target_dir: @target_dir)

    refute_symlink File.join(@target_dir, "tdd")
    assert_reported_action @reporter, :would_link, name: "tdd"
  end

  def test_reports_warning_when_no_skills
    installer.install({}, target_dir: @target_dir)

    assert_includes @reporter.warnings, "no skills to install"
  end

  def test_links_multiple_skills
    tdd_source = create_dir("source/tdd")
    reviewer_source = create_dir("source/reviewer")
    skills = {"tdd" => tdd_source, "reviewer" => reviewer_source}

    installer.install(skills, target_dir: @target_dir)

    assert_symlink File.join(@target_dir, "tdd")
    assert_symlink File.join(@target_dir, "reviewer")
  end

  private

  def installer
    SkillInstaller.new(linker: @linker, reporter: @reporter)
  end
end
