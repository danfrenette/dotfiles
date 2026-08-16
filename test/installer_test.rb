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
  end

  def test_full_install_runs_expected_phases_and_completion
    create_skill("engineering/tdd")
    build_installer(config: {local_skills: ["engineering/tdd"]}).install

    assert_equal ["Linking dotfiles", "Installing skills", "Post-install"], @reporter.phases
    assert @reporter.completion_reported
    assert_reported_action @reporter, :linked, name: "tdd"
  end

  def test_plans_confirms_and_applies_mappings
    source, target = create_mapping("gitconfig")
    prompt = TestPrompt.new(true)

    status = build_installer(
      options: {only: :mappings},
      config: {mappings: {source => target}},
      runtime: {prompt: prompt}
    ).install

    assert_equal 0, status
    assert_equal [
      {type: :create_directory, meta: {path: File.dirname(target)}},
      {type: :create_symlink, meta: {source: source, target: target}}
    ], @reporter.actions.first(2)
    assert_symlink target, to: source
  end

  def test_declined_confirmation_cancels_without_changes
    source, target = create_mapping("gitconfig")
    prompt = TestPrompt.new(false)

    status = build_installer(
      options: {only: :mappings},
      config: {mappings: {source => target}},
      runtime: {prompt: prompt}
    ).install

    assert_equal 0, status
    refute File.exist?(target)
    refute @reporter.completion_reported
  end

  def test_dry_run_reports_plan_without_prompting_or_mutating
    source, target = create_mapping("gitconfig")
    prompt = TestPrompt.new { raise "dry run prompted" }

    status = build_installer(
      options: {only: :mappings, dry_run: true},
      config: {mappings: {source => target}},
      runtime: {prompt: prompt}
    ).install

    assert_equal 0, status
    assert @reporter.dry_completion_reported
    refute File.exist?(target)
  end

  def test_yes_applies_plan_without_prompting
    source, target = create_mapping("gitconfig")
    prompt = TestPrompt.new { raise "--yes prompted" }

    status = build_installer(
      options: {only: :mappings, yes: true},
      config: {mappings: {source => target}},
      runtime: {prompt: prompt}
    ).install

    assert_equal 0, status
    assert_symlink target, to: source
  end

  def test_missing_source_late_in_manifest_prevents_all_mapping_changes
    source, first_target = create_mapping("gitconfig")
    missing_source = tmp_path("dotfiles/missing")
    second_target = tmp_path("home/.missing")

    status = build_installer(
      options: {only: :mappings, yes: true},
      config: {mappings: {source => first_target, missing_source => second_target}}
    ).install

    assert_equal 1, status
    assert_includes @reporter.warnings, "Source does not exist: #{missing_source}"
    refute File.exist?(first_target)
    refute File.exist?(second_target)
  end

  def test_blocked_parent_late_in_manifest_prevents_all_mapping_changes
    first_source, first_target = create_mapping("first")
    second_source, = create_mapping("second")
    blocked_parent = create_file("home/blocked")
    second_target = File.join(blocked_parent, "second")

    status = build_installer(
      options: {only: :mappings, yes: true},
      config: {mappings: {first_source => first_target, second_source => second_target}}
    ).install

    assert_equal 1, status
    assert_includes @reporter.warnings, "Cannot create parent directory: #{blocked_parent}"
    refute File.exist?(first_target)
  end

  def test_plans_and_applies_existing_file_replacement
    source, target = create_mapping("gitconfig", "new")
    create_file(target, "old")

    status = build_installer(
      options: {only: :mappings, yes: true},
      config: {mappings: {source => target}}
    ).install

    assert_equal 0, status
    assert_equal [
      {type: :move, meta: {source: target, target: "#{target}.backup"}},
      {type: :create_symlink, meta: {source: source, target: target}}
    ], @reporter.actions.first(2)
    assert_symlink target, to: source
    assert_equal "old", File.read("#{target}.backup")
  end

  def test_plans_existing_backup_removal_before_replacement
    source, target = create_mapping("gitconfig", "new")
    create_file(target, "old")
    backup = create_file("#{target}.backup", "older")

    status = build_installer(
      options: {only: :mappings, yes: true},
      config: {mappings: {source => target}}
    ).install

    assert_equal 0, status
    assert_equal [
      {type: :remove, meta: {path: backup}},
      {type: :move, meta: {source: target, target: backup}},
      {type: :create_symlink, meta: {source: source, target: target}}
    ], @reporter.actions.first(3)
    assert_equal "old", File.read(backup)
  end

  def test_correct_link_is_unchanged_on_repeated_runs
    source, target = create_mapping("gitconfig")
    installer = build_installer(
      options: {only: :mappings, yes: true},
      config: {mappings: {source => target}}
    )
    installer.install
    @reporter.clear

    status = installer.install

    assert_equal 0, status
    assert_equal [
      {type: :unchanged, meta: {source: source, target: target}}
    ], @reporter.actions
    assert_symlink target, to: source
    refute File.exist?("#{target}.backup")
  end

  def test_only_mappings_excludes_unrelated_phases
    source, target = create_mapping("gitconfig")
    create_skill("engineering/tdd")

    status = build_installer(
      options: {skip_brew: false, only: :mappings, yes: true},
      config: {mappings: {source => target}, local_skills: ["engineering/tdd"]}
    ).install

    assert_equal 0, status
    assert_equal ["Linking dotfiles"], @reporter.phases
    assert_symlink target, to: source
    refute File.exist?(skill_target("tdd"))
  end

  def test_default_setup_runs_full_setup_without_mapping_confirmation
    source, target = create_mapping("gitconfig")
    brewfile = create_file("dotfiles/Brewfile")
    command_runner = TestCommandRunner.new
    prompt = TestPrompt.new { raise "default setup prompted" }
    create_skill("engineering/tdd")

    status = build_installer(
      options: {skip_brew: false},
      config: {
        mappings: {source => target},
        brewfile_path: brewfile,
        local_skills: ["engineering/tdd"]
      },
      runtime: {command_runner: command_runner, prompt: prompt}
    ).install

    assert_equal 0, status
    assert_equal [["brew", "bundle", "--file=#{brewfile}"]], command_runner.calls
    assert_symlink target, to: source
    assert_symlink skill_target("tdd")
  end

  def test_default_dry_run_reports_full_setup_without_execution
    source, target = create_mapping("gitconfig")
    brewfile = create_file("dotfiles/Brewfile")
    nvim_init = tmp_path("home/.config/nvim/init.lua")
    command_runner = TestCommandRunner.new
    prompt = TestPrompt.new { raise "default dry run prompted" }
    create_skill("engineering/tdd")

    status = build_installer(
      options: {skip_brew: false, dry_run: true},
      config: {
        mappings: {source => target},
        brewfile_path: brewfile,
        nvim_init_target: nvim_init,
        local_skills: ["engineering/tdd"]
      },
      runtime: {command_runner: command_runner, prompt: prompt}
    ).install

    assert_equal 0, status
    assert_equal ["Installing Homebrew packages", "Linking dotfiles", "Installing skills", "Post-install"], @reporter.phases
    assert_empty command_runner.calls
    refute File.exist?(target)
    refute File.exist?(skill_target("tdd"))
    refute @reporter.actions.any? { |action| action[:meta][:message] == "would run nvim --headless +PlugInstall +qa" }
    assert @reporter.dry_completion_reported
  end

  def test_default_dry_run_reports_nvim_when_mapping_will_create_its_config
    source = create_file("dotfiles/init.lua")
    nvim_init = tmp_path("home/.config/nvim/init.lua")

    status = build_installer(
      options: {dry_run: true},
      config: {
        mappings: {source => nvim_init},
        nvim_init_target: nvim_init
      }
    ).install

    assert_equal 0, status
    assert @reporter.actions.any? { |action| action[:meta][:message] == "would run nvim --headless +PlugInstall +qa" }
    refute File.exist?(nvim_init)
  end

  def test_installs_explicit_local_skills_from_manifest
    create_skill("engineering/tdd")
    build_installer(config: {local_skills: ["engineering/tdd"]}).install

    assert_symlink skill_target("tdd"), to: File.join(@skills_root, "engineering", "tdd")
  end

  def test_skills_only_installs_skills_without_linking_dotfiles
    create_skill("engineering/tdd")
    status = build_installer(
      options: {skip_brew: false, skills_only: true},
      config: {local_skills: ["engineering/tdd"]}
    ).install

    assert_equal 0, status
    assert_symlink skill_target("tdd")
    assert_includes @reporter.phases, "Installing skills"
    refute_includes @reporter.phases, "Linking dotfiles"
    refute_includes @reporter.phases, "Post-install"
  end

  private

  def build_installer(options: {}, config: {}, runtime: {})
    local_skills = config.fetch(:local_skills, [])
    write_skills_manifest(@skills_manifest, local_skills: local_skills)

    setup_config = TestConfig.new(
      skills_source_root: @skills_root,
      opencode_skills_target: @skills_target,
      local_skills: local_skills,
      skills_manifest_path: @skills_manifest,
      mappings: config.fetch(:mappings, {}),
      brewfile_path: config.fetch(:brewfile_path, "/nonexistent/Brewfile"),
      nvim_init_target: config.fetch(:nvim_init_target, "/nonexistent/path/init.lua")
    )

    Installer.new(
      options: SetupOptions.new(skip_brew: true, **options),
      config: setup_config,
      runtime: SetupRuntime.new(reporter: @reporter, **runtime)
    )
  end

  def create_skill(path)
    super(path, root: @skills_root)
  end

  def skill_target(name)
    File.join(@skills_target, name)
  end
end
