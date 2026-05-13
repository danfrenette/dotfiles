# frozen_string_literal: true

require "test_helper"
require "installer"
require "reporters/test_reporter"

class InstallerTest < DotfilesTestCase
  def setup
    super
    @reporter = Reporters::TestReporter.new
    @skills_root = tmp_path("skills")
    @skills_target = tmp_path("opencode/skill")
    @skills_manifest = tmp_path("skills.yml")
    @skills_lock = tmp_path("skills.lock")
    @skills_cache = tmp_path("cache")
  end

  def test_full_install_runs_expected_phases_and_completion
    create_skill("engineering/tdd")
    build_installer(skip_brew: true, local_skills: ["engineering/tdd"]).install

    assert_equal ["Linking dotfiles", "Installing skills", "Post-install"], @reporter.phases
    assert @reporter.completion_reported
    assert_reported_action @reporter, :linked, name: "tdd"
  end

  def test_installs_explicit_local_skills_from_manifest
    create_skill("engineering/tdd")
    build_installer(skip_brew: true, local_skills: ["engineering/tdd"]).install

    assert_symlink skill_target("tdd"), to: File.join(@skills_root, "engineering", "tdd")
  end

  def test_skills_only_installs_skills_without_linking_dotfiles
    create_skill("engineering/tdd")
    build_installer(skip_brew: false, skills_only: true, local_skills: ["engineering/tdd"]).install

    assert_symlink skill_target("tdd")
    assert_includes @reporter.phases, "Installing skills"
    refute_includes @reporter.phases, "Linking dotfiles"
    refute_includes @reporter.phases, "Post-install"
  end

  def test_dry_run_reports_would_link_actions
    create_skill("engineering/tdd")
    build_installer(skip_brew: true, dry_run: true, local_skills: ["engineering/tdd"]).install

    assert_includes @reporter.action_types, :would_link
    assert @reporter.dry_completion_reported
  end

  private

  def build_installer(skip_brew:, dry_run: false, skills_only: false, local_skills: [])
    write_skills_manifest(@skills_manifest, local_skills: local_skills)

    config = TestConfig.new(
      skills_source_root: @skills_root,
      opencode_skills_target: @skills_target,
      local_skills: local_skills,
      skills_manifest_path: @skills_manifest,
      skills_lock_path: @skills_lock,
      skills_cache_dir: @skills_cache
    )

    Installer.new(
      reporter: @reporter,
      skip_brew: skip_brew,
      dry_run: dry_run,
      skills_only: skills_only,
      config: config
    )
  end

  def create_skill(path)
    super(path, root: @skills_root)
  end

  def skill_target(name)
    File.join(@skills_target, name)
  end
end
