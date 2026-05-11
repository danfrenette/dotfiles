# frozen_string_literal: true

require "test_helper"
require "skill_installer"
require "reporters/test_reporter"

class SkillInstallerTest < DotfilesTestCase
  def setup
    super
    @reporter = Reporters::TestReporter.new
    @remote_sources = FakeRemoteSources.new
    @config = MockConfig.new(tmp_path("skills"), tmp_path("opencode/skill"), tmp_path("skills.yml"), tmp_path("skills.lock"), tmp_path("cache"))
  end

  def test_discovers_skill_directories_from_skill_files
    tdd = create_skill("engineering/tdd")
    reviewer = create_skill("engineering/reviewer")

    skills = installer.skill_sources

    assert_equal tdd, skills["tdd"]
    assert_equal reviewer, skills["reviewer"]
  end

  def test_excludes_deprecated_skills
    create_skill("deprecated/old-skill")

    assert_empty installer.skill_sources
  end

  def test_links_each_skill_directory
    source = create_skill("engineering/tdd")

    installer.install

    target = File.join(@config.opencode_skills_target, "tdd")
    assert File.symlink?(target)
    assert_equal source, File.readlink(target)
  end

  def test_links_remote_skill_directories
    source = create_skill("remote/reviewer")
    @remote_sources.sources = {"reviewer" => source}

    installer.install

    target = File.join(@config.opencode_skills_target, "reviewer")
    assert File.symlink?(target)
    assert_equal source, File.readlink(target)
  end

  def test_skips_already_linked_skill
    source = create_skill("engineering/tdd")
    target = File.join(@config.opencode_skills_target, "tdd")
    FileUtils.mkdir_p(File.dirname(target))
    File.symlink(source, target)

    installer.install

    assert @reporter.action_named("tdd")
    assert_equal :already_linked, @reporter.action_named("tdd")[:type]
  end

  def test_backs_up_existing_target_directory
    source = create_skill("engineering/tdd")
    target = create_dir(File.join(@config.opencode_skills_target, "tdd"))
    create_file(File.join(target, "old.md"), "old")

    installer.install

    assert File.symlink?(target)
    assert_equal source, File.readlink(target)
    assert File.exist?("#{target}.backup/old.md")
  end

  def test_dry_run_does_not_link_skill
    create_skill("engineering/tdd")

    SkillInstaller.new(dry_run: true, config: @config, remote_sources: @remote_sources, reporter: @reporter).install

    refute File.exist?(File.join(@config.opencode_skills_target, "tdd"))
    assert_includes @reporter.action_types, :would_link
  end

  def test_raises_when_destination_symlinks_into_source_root
    create_dir(@config.skills_source_root)
    FileUtils.mkdir_p(File.dirname(@config.opencode_skills_target))
    File.symlink(@config.skills_source_root, @config.opencode_skills_target)

    error = assert_raises(RuntimeError) { installer.install }
    assert_match(/symlink into this repo/, error.message)
  end

  private

  def installer
    SkillInstaller.new(config: @config, remote_sources: @remote_sources, reporter: @reporter)
  end

  def create_skill(path)
    skill_dir = File.join(@config.skills_source_root, path)
    create_file(File.join(skill_dir, "SKILL.md"), "---\nname: #{File.basename(path)}\n---\n")
    skill_dir
  end

  class MockConfig
    attr_reader :skills_source_root, :opencode_skills_target, :skills_manifest_path, :skills_lock_path, :skills_cache_dir

    def initialize(skills_source_root, opencode_skills_target, skills_manifest_path, skills_lock_path, skills_cache_dir)
      @skills_source_root = skills_source_root
      @opencode_skills_target = opencode_skills_target
      @skills_manifest_path = skills_manifest_path
      @skills_lock_path = skills_lock_path
      @skills_cache_dir = skills_cache_dir
    end
  end

  class FakeRemoteSources
    attr_writer :sources

    def sources(update: false)
      @update = update
      @sources || {}
    end
  end
end
