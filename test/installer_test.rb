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
      config: {mappings: [mapping(source, target)]},
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
      config: {mappings: [mapping(source, target)]},
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
      config: {mappings: [mapping(source, target)]},
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
      config: {mappings: [mapping(source, target)]},
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
      config: {mappings: [mapping(source, first_target), mapping(missing_source, second_target)]}
    ).install

    assert_equal 1, status
    assert_includes @reporter.warnings, "Source does not exist: #{missing_source}"
    refute File.exist?(first_target)
    refute File.exist?(second_target)
  end

  def test_manifest_source_symlink_escape_prevents_all_mapping_changes
    repository_root = create_dir("manifest-repository")
    home_root = create_dir("manifest-home")
    outside = create_dir("outside")
    create_file("manifest-repository/safe", "safe")
    create_file("outside/secret", "secret")
    File.symlink(outside, File.join(repository_root, "escaped"))
    manifest_path = create_file("escape-mappings.yml", <<~YAML)
      mappings:
        - operation: link
          source: safe
          target: .safe
        - operation: copy
          source: escaped/secret
          target: .secret
    YAML

    status = build_manifest_installer(repository_root, home_root, manifest_path).install

    assert_equal 1, status
    assert @reporter.warnings.any? { |warning| warning.include?("source parent escapes repository root") }
    refute File.exist?(File.join(home_root, ".safe"))
    refute File.exist?(File.join(home_root, ".secret"))
  end

  def test_manifest_backup_collision_preserves_all_targets
    repository_root = create_dir("collision-repository")
    home_root = create_dir("collision-home")
    create_file("collision-repository/first", "new first")
    create_file("collision-repository/second", "new second")
    target = create_file("collision-home/x", "old first")
    backup_target = create_file("collision-home/x.backup", "valid second")
    manifest_path = create_file("collision-mappings.yml", <<~YAML)
      mappings:
        - operation: copy
          source: first
          target: x
        - operation: copy
          source: second
          target: x.backup
    YAML

    status = build_manifest_installer(repository_root, home_root, manifest_path).install

    assert_equal 1, status
    assert @reporter.warnings.any? { |warning| warning.include?("backup path overlaps mapping target") }
    assert_equal "old first", File.read(target)
    assert_equal "valid second", File.read(backup_target)
  end

  def test_blocked_parent_late_in_manifest_prevents_all_mapping_changes
    first_source, first_target = create_mapping("first")
    second_source, = create_mapping("second")
    blocked_parent = create_file("home/blocked")
    second_target = File.join(blocked_parent, "second")

    status = build_installer(
      options: {only: :mappings, yes: true},
      config: {mappings: [mapping(first_source, first_target), mapping(second_source, second_target)]}
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
      config: {mappings: [mapping(source, target)]}
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
      config: {mappings: [mapping(source, target)]}
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
      config: {mappings: [mapping(source, target)]}
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

  def test_plans_and_applies_link_and_copy_mappings_in_manifest_order
    link_source, link_target = create_mapping("linked")
    copy_source, copy_target = create_mapping("copied")

    status = build_installer(
      options: {only: :mappings, yes: true},
      config: {
        mappings: [mapping(link_source, link_target), mapping(copy_source, copy_target, operation: :copy)]
      }
    ).install

    assert_equal 0, status
    assert_equal [:create_directory, :create_symlink, :create_directory, :create_copy], @reporter.action_types
    assert_symlink link_target, to: link_source
    refute File.symlink?(copy_target)
    assert_equal File.read(copy_source), File.read(copy_target)
  end

  def test_removed_mapping_is_left_untouched
    first_source, first_target = create_mapping("first")
    second_source, second_target = create_mapping("second")
    build_installer(
      options: {only: :mappings, yes: true},
      config: {mappings: [mapping(first_source, first_target), mapping(second_source, second_target)]}
    ).install

    build_installer(
      options: {only: :mappings, yes: true},
      config: {mappings: [mapping(first_source, first_target)]}
    ).install

    assert_symlink second_target, to: second_source
    refute File.exist?("#{second_target}.backup")
  end

  def test_declined_copy_plan_creates_no_target_or_staging_directory
    source, target = create_mapping("copied")

    status = build_installer(
      options: {only: :mappings},
      config: {mappings: [mapping(source, target, operation: :copy)]},
      runtime: {prompt: TestPrompt.new(false)}
    ).install

    assert_equal 0, status
    refute File.exist?(target)
    assert_empty Dir.glob(File.join(File.dirname(target), ".dotfiles-stage-*"))
  end

  def test_only_mappings_excludes_unrelated_phases
    source, target = create_mapping("gitconfig")
    create_skill("engineering/tdd")

    status = build_installer(
      options: {skip_brew: false, only: :mappings, yes: true},
      config: {mappings: [mapping(source, target)], local_skills: ["engineering/tdd"]}
    ).install

    assert_equal 0, status
    assert_equal ["Linking dotfiles"], @reporter.phases
    assert_symlink target, to: source
    refute File.exist?(skill_target("tdd"))
  end

  def test_homebrew_dry_run_reports_exact_plan_without_execution
    brewfile = create_file("dotfiles/Brewfile")
    command_runner = TestCommandRunner.new(executables: {"brew" => "/opt/homebrew/bin/brew"})
    prompt = TestPrompt.new { raise "dry run prompted" }

    status = build_installer(
      options: {only: :homebrew, dry_run: true},
      config: {brewfile_path: brewfile},
      runtime: {command_runner: command_runner, prompt: prompt}
    ).install

    assert_equal 0, status
    availability = @reporter.actions.find { |action| action[:type] == :available }
    bundle = @reporter.actions.find { |action| action[:type] == :bundle }
    assert_equal "/opt/homebrew/bin/brew", availability[:meta][:path]
    assert_equal brewfile, bundle[:meta][:brewfile]
    assert_equal "install or update declared packages", bundle[:meta][:effect]
    assert_empty command_runner.calls
    assert @reporter.dry_completion_reported
  end

  def test_homebrew_missing_executable_fails_before_prompt_or_execution
    prompt = TestPrompt.new { raise "missing Homebrew prompted" }
    command_runner = TestCommandRunner.new

    status = build_installer(
      options: {only: :homebrew},
      config: {brewfile_path: create_file("dotfiles/Brewfile")},
      runtime: {command_runner: command_runner, prompt: prompt}
    ).install

    assert_equal 1, status
    assert_includes @reporter.warnings, "Homebrew not found; run ./bootstrap.sh first"
    assert_empty command_runner.calls
  end

  def test_homebrew_rejects_missing_directory_and_unreadable_brewfiles
    missing = tmp_path("dotfiles/missing-Brewfile")
    directory = create_dir("dotfiles/Brewfile-directory")
    unreadable = create_file("dotfiles/unreadable-Brewfile")
    FileUtils.chmod(0o000, unreadable)

    expected_errors = {
      missing => "Brewfile not found: #{missing}",
      directory => "Brewfile is not a regular file: #{directory}",
      unreadable => "Brewfile is not readable: #{unreadable}"
    }

    expected_errors.each do |brewfile, error|
      @reporter.clear
      command_runner = TestCommandRunner.new(executables: {"brew" => "/usr/local/bin/brew"})

      status = build_installer(
        options: {only: :homebrew, yes: true},
        config: {brewfile_path: brewfile},
        runtime: {command_runner: command_runner}
      ).install

      assert_equal 1, status
      assert_includes @reporter.warnings, error
      assert_empty command_runner.calls
    end
  ensure
    FileUtils.chmod(0o600, unreadable) if unreadable && File.exist?(unreadable)
  end

  def test_declined_homebrew_confirmation_executes_nothing
    brewfile = create_file("dotfiles/Brewfile")
    command_runner = TestCommandRunner.new(executables: {"brew" => "/opt/homebrew/bin/brew"})

    status = build_installer(
      options: {only: :homebrew},
      config: {brewfile_path: brewfile},
      runtime: {command_runner: command_runner, prompt: TestPrompt.new(false)}
    ).install

    assert_equal 0, status
    assert_empty command_runner.calls
    refute @reporter.completion_reported
  end

  def test_confirmed_homebrew_runs_exact_planned_command
    brewfile = create_file("dotfiles/Brewfile")
    command_runner = TestCommandRunner.new(executables: {"brew" => "/opt/homebrew/bin/brew"})

    status = build_installer(
      options: {only: :homebrew},
      config: {brewfile_path: brewfile},
      runtime: {command_runner: command_runner, prompt: TestPrompt.new(true)}
    ).install

    assert_equal 0, status
    assert_equal [["/opt/homebrew/bin/brew", "bundle", "--file=#{brewfile}"]], command_runner.calls
    assert @reporter.completion_reported
  end

  def test_homebrew_yes_bypasses_confirmation
    brewfile = create_file("dotfiles/Brewfile")
    command_runner = TestCommandRunner.new(executables: {"brew" => "/usr/local/bin/brew"})
    prompt = TestPrompt.new { raise "--yes prompted" }

    status = build_installer(
      options: {only: :homebrew, yes: true},
      config: {brewfile_path: brewfile},
      runtime: {command_runner: command_runner, prompt: prompt}
    ).install

    assert_equal 0, status
    assert_equal [["/usr/local/bin/brew", "bundle", "--file=#{brewfile}"]], command_runner.calls
  end

  def test_homebrew_nonzero_and_failed_start_are_blocking
    {false => "brew bundle exited with a nonzero status", nil => "brew bundle could not start"}.each do |result, error|
      @reporter.clear
      brewfile = create_file("dotfiles/Brewfile")
      command_runner = TestCommandRunner.new(
        result: result,
        executables: {"brew" => "/opt/homebrew/bin/brew"}
      )

      status = build_installer(
        options: {only: :homebrew, yes: true},
        config: {brewfile_path: brewfile},
        runtime: {command_runner: command_runner}
      ).install

      assert_equal 1, status
      assert_includes @reporter.warnings, error
      refute @reporter.completion_reported
    end
  end

  def test_homebrew_only_excludes_mappings_skills_and_neovim
    source, target = create_mapping("gitconfig")
    brewfile = create_file("dotfiles/Brewfile")
    command_runner = TestCommandRunner.new(executables: {"brew" => "/opt/homebrew/bin/brew"})
    create_skill("engineering/tdd")

    status = build_installer(
      options: {only: :homebrew, yes: true},
      config: {
        mappings: [mapping(source, target)],
        brewfile_path: brewfile,
        local_skills: ["engineering/tdd"]
      },
      runtime: {command_runner: command_runner}
    ).install

    assert_equal 0, status
    assert_equal ["Installing Homebrew packages"], @reporter.phases
    refute File.exist?(target)
    refute File.exist?(skill_target("tdd"))
  end

  def test_default_mapping_preflight_failure_prevents_homebrew_execution
    brewfile = create_file("dotfiles/Brewfile")
    missing_source = tmp_path("dotfiles/missing")
    command_runner = TestCommandRunner.new(executables: {"brew" => "/opt/homebrew/bin/brew"})

    status = build_installer(
      options: {skip_brew: false},
      config: {
        mappings: [mapping(missing_source, tmp_path("home/.missing"))],
        brewfile_path: brewfile
      },
      runtime: {command_runner: command_runner}
    ).install

    assert_equal 1, status
    assert_empty command_runner.calls
  end

  def test_default_homebrew_failure_stops_before_later_phases
    source, target = create_mapping("gitconfig")
    brewfile = create_file("dotfiles/Brewfile")
    command_runner = TestCommandRunner.new(
      result: false,
      executables: {"brew" => "/opt/homebrew/bin/brew"}
    )
    create_skill("engineering/tdd")

    status = build_installer(
      options: {skip_brew: false},
      config: {
        mappings: [mapping(source, target)],
        brewfile_path: brewfile,
        local_skills: ["engineering/tdd"]
      },
      runtime: {command_runner: command_runner}
    ).install

    assert_equal 1, status
    refute File.exist?(target)
    refute File.exist?(skill_target("tdd"))
    refute_includes @reporter.phases, "Installing skills"
    refute_includes @reporter.phases, "Post-install"
  end

  def test_default_setup_runs_full_setup_without_mapping_confirmation
    source, target = create_mapping("gitconfig")
    brewfile = create_file("dotfiles/Brewfile")
    command_runner = TestCommandRunner.new(executables: {"brew" => "/opt/homebrew/bin/brew"})
    prompt = TestPrompt.new { raise "default setup prompted" }
    create_skill("engineering/tdd")

    status = build_installer(
      options: {skip_brew: false},
      config: {
        mappings: [mapping(source, target)],
        brewfile_path: brewfile,
        local_skills: ["engineering/tdd"]
      },
      runtime: {command_runner: command_runner, prompt: prompt}
    ).install

    assert_equal 0, status
    assert_equal [["/opt/homebrew/bin/brew", "bundle", "--file=#{brewfile}"]], command_runner.calls
    assert_symlink target, to: source
    assert_symlink skill_target("tdd")
  end

  def test_default_dry_run_reports_full_setup_without_execution
    source, target = create_mapping("gitconfig")
    brewfile = create_file("dotfiles/Brewfile")
    nvim_init = tmp_path("home/.config/nvim/init.lua")
    command_runner = TestCommandRunner.new(executables: {"brew" => "/opt/homebrew/bin/brew"})
    prompt = TestPrompt.new { raise "default dry run prompted" }
    create_skill("engineering/tdd")

    status = build_installer(
      options: {skip_brew: false, dry_run: true},
      config: {
        mappings: [mapping(source, target)],
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
        mappings: [mapping(source, nvim_init)],
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

  def build_manifest_installer(repository_root, home_root, manifest_path)
    Installer.new(
      options: SetupOptions.new(skip_brew: true, only: :mappings, yes: true),
      config: Config.new(
        repository_root: repository_root,
        home_root: home_root,
        mappings_path: manifest_path
      ),
      runtime: SetupRuntime.new(reporter: @reporter)
    )
  end

  def build_installer(options: {}, config: {}, runtime: {})
    local_skills = config.fetch(:local_skills, [])
    write_skills_manifest(@skills_manifest, local_skills: local_skills)

    setup_config = TestConfig.new(
      skills_source_root: @skills_root,
      opencode_skills_target: @skills_target,
      local_skills: local_skills,
      skills_manifest_path: @skills_manifest,
      mappings: config.fetch(:mappings, []),
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
