# frozen_string_literal: true

require "test_helper"
require "installer"

class InstallerTest < DotfilesTestCase
  def setup
    super
    @reporter = Reporters::TestReporter.new
  end

  def test_full_install_runs_expected_phases_and_completion
    build_installer.install

    assert_equal ["Installing OpenCode2", "Linking dotfiles", "Installing skills", "Installing Neovim plugins"], @reporter.phases
    assert @reporter.completion_reported
    assert_includes @reporter.planned_actions.map { |action| action[:label] }, :skills
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
    assert @reporter.completion_reported
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
        - source: safe
          target: .safe
        - source: escaped/secret
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
        - source: first
          target: x
        - source: second
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

  def test_plans_and_applies_mappings_in_manifest_order
    first_source, first_target = create_mapping("first")
    second_source, second_target = create_mapping("second")

    status = build_installer(
      options: {only: :mappings, yes: true},
      config: {mappings: [mapping(first_source, first_target), mapping(second_source, second_target)]}
    ).install

    assert_equal 0, status
    assert_equal [:create_directory, :create_symlink, :create_directory, :create_symlink], @reporter.action_types
    assert_symlink first_target, to: first_source
    assert_symlink second_target, to: second_source
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

  def test_only_mappings_excludes_unrelated_phases
    source, target = create_mapping("gitconfig")

    status = build_installer(
      options: {skip_brew: false, only: :mappings, yes: true},
      config: {mappings: [mapping(source, target)]}
    ).install

    assert_equal 0, status
    assert_equal ["Linking dotfiles"], @reporter.phases
    assert_symlink target, to: source
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
    availability = @reporter.planned_actions.find do |action|
      action[:label] == :ok && action[:message].start_with?("Homebrew executable:")
    end
    trust = @reporter.planned_actions.select { |action| action[:label] == :trust }
    sudo = @reporter.planned_actions.find { |action| action[:label] == :sudo }
    bundle = @reporter.planned_actions.find { |action| action[:label] == :brew }
    assert_equal "Homebrew executable: /opt/homebrew/bin/brew", availability[:message]
    assert_includes @reporter.planned_actions,
      {label: :ok, message: "Apple developer tools meet Homebrew requirements"}
    assert_equal ["/opt/homebrew/bin/brew trust --formula oven-sh/bun/bun"], trust.map { |action| action[:message] }
    assert_equal "sudo -v (authenticate once for privileged casks)", sudo[:message]
    assert_includes bundle[:message], "--file=#{brewfile}"
    assert_includes bundle[:message], "install or update declared packages"
    assert_empty command_runner.calls
    assert_equal [
      ["xcode-select", "-p"],
      ["xcodebuild", "-license", "check"],
      ["/opt/homebrew/bin/brew", "doctor", "check_clt_minimum_version"],
      ["/opt/homebrew/bin/brew", "doctor", "check_xcode_minimum_version"]
    ], command_runner.capture_calls
    assert @reporter.dry_completion_reported
  end

  def test_homebrew_rejects_outdated_apple_developer_tools_during_preflight
    brewfile = create_file("dotfiles/Brewfile")
    command_runner = TestCommandRunner.new(
      executables: {"brew" => "/opt/homebrew/bin/brew"},
      captures: {"brew" => nil}
    )

    status = build_installer(
      options: {only: :homebrew, dry_run: true},
      config: {brewfile_path: brewfile},
      runtime: {command_runner: command_runner}
    ).install

    assert_equal 1, status
    assert_includes @reporter.warnings,
      "Apple developer tools are missing or outdated.\n" \
      "Open Software Update:\n" \
      "  open 'x-apple.systempreferences:com.apple.Software-Update-Settings.extension'\n" \
      "Update Xcode too if installed:\n" \
      "  open 'macappstore://itunes.apple.com/app/id497799835'\n" \
      "Then rerun: dotfiles setup"
    assert_empty command_runner.calls
  end

  def test_homebrew_rejects_an_unaccepted_xcode_license_during_preflight
    brewfile = create_file("dotfiles/Brewfile")
    command_runner = TestCommandRunner.new(
      executables: {"brew" => "/opt/homebrew/bin/brew"},
      captures: {"xcodebuild" => nil}
    )

    status = build_installer(
      options: {only: :homebrew, dry_run: true},
      config: {brewfile_path: brewfile},
      runtime: {command_runner: command_runner}
    ).install

    assert_equal 1, status
    assert_includes @reporter.warnings,
      "Xcode license has not been accepted.\nRun:\n  sudo xcodebuild -license accept\nThen rerun: dotfiles setup"
    assert_empty command_runner.calls
    assert_equal [["xcode-select", "-p"], ["xcodebuild", "-license", "check"]], command_runner.capture_calls
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
    assert_equal [
      ["/opt/homebrew/bin/brew", "trust", "--formula", "oven-sh/bun/bun"],
      ["sudo", "-v"],
      ["/opt/homebrew/bin/brew", "bundle", "--file=#{brewfile}"]
    ], command_runner.calls
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
    assert_equal [
      ["/usr/local/bin/brew", "trust", "--formula", "oven-sh/bun/bun"],
      ["sudo", "-v"],
      ["/usr/local/bin/brew", "bundle", "--file=#{brewfile}"]
    ], command_runner.calls
  end

  def test_homebrew_nonzero_and_failed_start_are_blocking
    {false => "brew bundle exited with a nonzero status", nil => "brew bundle could not start"}.each do |result, error|
      @reporter.clear
      brewfile = create_file("dotfiles/Brewfile")
      command_runner = TestCommandRunner.new(
        results: [true, true, result],
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

  def test_homebrew_trust_failure_stops_before_bundling
    brewfile = create_file("dotfiles/Brewfile")
    command_runner = TestCommandRunner.new(
      results: [false],
      executables: {"brew" => "/opt/homebrew/bin/brew"}
    )

    status = build_installer(
      options: {only: :homebrew, yes: true},
      config: {brewfile_path: brewfile},
      runtime: {command_runner: command_runner}
    ).install

    assert_equal 1, status
    assert_includes @reporter.warnings, "brew trust exited with a nonzero status"
    assert_equal [["/opt/homebrew/bin/brew", "trust", "--formula", "oven-sh/bun/bun"]], command_runner.calls
  end

  def test_homebrew_sudo_failure_stops_before_bundling
    brewfile = create_file("dotfiles/Brewfile")
    command_runner = TestCommandRunner.new(
      results: [true, false],
      executables: {"brew" => "/opt/homebrew/bin/brew"}
    )

    status = build_installer(
      options: {only: :homebrew, yes: true},
      config: {brewfile_path: brewfile},
      runtime: {command_runner: command_runner}
    ).install

    assert_equal 1, status
    assert_includes @reporter.warnings, "sudo authentication failed"
    assert_equal [
      ["/opt/homebrew/bin/brew", "trust", "--formula", "oven-sh/bun/bun"],
      ["sudo", "-v"]
    ], command_runner.calls
  end

  def test_homebrew_only_excludes_mappings_skills_and_neovim
    source, target = create_mapping("gitconfig")
    brewfile = create_file("dotfiles/Brewfile")
    command_runner = TestCommandRunner.new(executables: {"brew" => "/opt/homebrew/bin/brew"})

    status = build_installer(
      options: {only: :homebrew, yes: true},
      config: {
        mappings: [mapping(source, target)],
        brewfile_path: brewfile
      },
      runtime: {command_runner: command_runner}
    ).install

    assert_equal 0, status
    assert_equal ["Installing Homebrew packages"], @reporter.phases
    refute File.exist?(target)
  end

  def test_neovim_only_requires_all_currently_mapped_configuration_targets
    targets = %w[init.lua lua/options.lua lua/plugins.lua lua/keymaps.lua lua/autocmds.lua].map do |path|
      tmp_path("home/.config/nvim/#{path}")
    end
    mappings = targets.map.with_index do |target, index|
      source = create_file("dotfiles/nvim/#{index}.lua")
      FileUtils.mkdir_p(File.dirname(target))
      File.symlink(source, target) unless index == targets.length - 1
      mapping(source, target)
    end
    runner = TestCommandRunner.new(executables: {"nvim" => "/fake/nvim", "pnpm" => "/fake/pnpm"})

    status = build_installer(
      options: {only: :neovim, yes: true},
      config: {mappings: mappings, nvim_configuration_targets: targets},
      runtime: {command_runner: runner}
    ).install

    assert_equal 1, status
    assert_includes @reporter.warnings, "Neovim configuration is not available: #{targets.last}"
    assert_empty runner.calls
  end

  def test_neovim_only_dry_run_and_confirmation_do_not_execute
    target = tmp_path("home/.config/nvim/init.lua")
    source = create_file("dotfiles/nvim/init.lua")
    FileUtils.mkdir_p(File.dirname(target))
    File.symlink(source, target)
    runner = TestCommandRunner.new(executables: {"nvim" => "/fake/nvim"})

    status = build_installer(
      options: {only: :neovim, dry_run: true},
      config: {mappings: [mapping(source, target)], nvim_configuration_targets: [target]},
      runtime: {command_runner: runner, prompt: TestPrompt.new { raise "dry run prompted" }}
    ).install

    assert_equal 0, status
    assert @reporter.dry_completion_reported
    assert_empty runner.calls
    assert_equal ["Installing Neovim plugins"], @reporter.phases
  end

  def test_skills_only_dry_run_reports_handoff_without_execution_or_other_phases
    runner = TestCommandRunner.new(executables: {"pnpm" => "/fake/pnpm"})

    status = build_installer(
      options: {only: :skills, dry_run: true},
      runtime: {command_runner: runner, prompt: TestPrompt.new { raise "dry run prompted" }}
    ).install

    assert_equal 0, status
    skills = @reporter.planned_actions.find { |action| action[:label] == :skills }
    assert_includes skills[:message], "/fake/pnpm dlx skills@1.5.23 add danfrenette/skills --global --agent opencode --agent cursor"
    assert_equal ["Installing skills"], @reporter.phases
    assert_empty runner.calls
    assert @reporter.dry_completion_reported
  end

  def test_neovim_only_accepts_current_linked_configuration
    source = create_file("dotfiles/nvim/init.lua", "require('plugins')")
    target = tmp_path("home/.config/nvim/init.lua")
    FileUtils.mkdir_p(File.dirname(target))
    File.symlink(source, target)
    runner = TestCommandRunner.new(executables: {"nvim" => "/fake/nvim"})

    status = build_installer(
      options: {only: :neovim, yes: true},
      config: {
        mappings: [mapping(source, target)],
        nvim_configuration_targets: [target]
      },
      runtime: {command_runner: runner}
    ).install

    assert_equal 0, status
    assert_equal [["/fake/nvim", "--headless", "+PlugInstall", "+qa"]], runner.calls
  end

  def test_opencode2_dry_run_skips_confirmation_execution_and_mutation
    home = tmp_path("home")
    global_dir = File.join(home, ".local", "share", "pnpm", "global")
    bin_dir = File.join(home, ".local", "bin")
    pnpm = "/opt/homebrew/bin/pnpm"
    git = "/usr/bin/git"
    bun = "/opt/homebrew/bin/bun"
    checkout = File.join(home, "code", "opencode")
    command_runner = TestCommandRunner.new(executables: {"pnpm" => pnpm, "git" => git, "bun" => bun})
    prompt = TestPrompt.new { raise "dry run prompted" }

    status = build_installer(
      options: {only: :opencode2, dry_run: true},
      config: {opencode2_global_dir: global_dir, user_bin_dir: bin_dir, opencode_fork_checkout: checkout},
      runtime: {command_runner: command_runner, prompt: prompt}
    ).install

    assert_equal 0, status
    assert_equal ["Installing OpenCode2"], @reporter.phases
    assert_empty command_runner.calls
    refute File.exist?(global_dir)
    refute File.exist?(bin_dir)
    refute File.exist?(checkout)
    assert @reporter.dry_completion_reported
  end

  def test_confirmed_opencode2_applies_phase_and_reports_completion
    global_dir = tmp_path("home/.local/share/pnpm/global")
    bin_dir = tmp_path("home/.local/bin")
    executable = File.join(bin_dir, "opencode2")
    pnpm = "/opt/homebrew/bin/pnpm"
    git = "/usr/bin/git"
    bun = "/opt/homebrew/bin/bun"
    checkout = tmp_path("home/code/opencode")
    command_runner = TestCommandRunner.new(
      executables: {"pnpm" => pnpm, "git" => git, "bun" => bun},
      on_run: lambda do |command, _options|
        if command.first == pnpm
          File.write(executable, "#!/bin/sh\n")
          FileUtils.chmod("+x", executable)
        elsif command.first == git
          create_opencode_fork(checkout)
        end
      end
    )

    status = build_installer(
      options: {only: :opencode2},
      config: {
        opencode2_global_dir: global_dir,
        user_bin_dir: bin_dir,
        opencode_fork_checkout: checkout
      },
      runtime: {command_runner: command_runner, prompt: TestPrompt.new(true)}
    ).install

    assert_equal 0, status
    assert File.directory?(global_dir)
    assert File.directory?(checkout)
    assert @reporter.completion_reported
  end

  def test_opencode2_application_failure_stops_setup_before_later_phases
    source, target = create_mapping("gitconfig")
    command_runner = TestCommandRunner.new(
      executables: {"pnpm" => "/fake/pnpm", "git" => "/fake/git", "bun" => "/fake/bun", "nvim" => "/fake/nvim"}
    )

    status = build_installer(
      options: {yes: true},
      config: {mappings: [mapping(source, target)]},
      runtime: {command_runner: command_runner}
    ).install

    assert_equal 1, status
    refute File.exist?(target)
    refute @reporter.completion_reported
    assert_includes @reporter.warnings,
      "OpenCode2 executable was not installed at #{tmp_path("home/.local/bin/opencode2")}"
  end

  def test_opencode2_preflight_failure_stops_setup_before_later_phases
    source, target = create_mapping("gitconfig")
    runner = TestCommandRunner.new(executables: {"nvim" => "/fake/nvim", "pnpm" => "/fake/pnpm"})

    status = build_installer(
      options: {yes: true},
      config: {mappings: [mapping(source, target)]},
      runtime: {command_runner: runner}
    ).install

    assert_equal 1, status
    refute File.exist?(target)
    refute_includes @reporter.phases, "Installing Neovim plugins"
    refute @reporter.completion_reported
    assert_includes @reporter.warnings, "Git not found; install Git before running the OpenCode2 phase"
    assert_empty runner.calls
  end

  def test_declined_opencode2_confirmation_mutates_and_executes_nothing
    runner = TestCommandRunner.new(
      executables: {"pnpm" => "/fake/pnpm", "git" => "/fake/git", "bun" => "/fake/bun", "nvim" => "/fake/nvim"}
    )

    status = build_installer(
      options: {only: :opencode2},
      runtime: {command_runner: runner, prompt: TestPrompt.new(false)}
    ).install

    assert_equal 0, status
    assert_empty runner.calls
    refute File.exist?(tmp_path("home/.local"))
    refute File.exist?(tmp_path("home/code"))
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
    command_runner = successful_full_command_runner({"brew" => "/opt/homebrew/bin/brew"}, result: false)

    status = build_installer(
      options: {skip_brew: false},
      config: {
        mappings: [mapping(source, target)],
        brewfile_path: brewfile
      },
      runtime: {command_runner: command_runner}
    ).install

    assert_equal 1, status
    refute File.exist?(target)
    assert_equal ["Installing Homebrew packages", "Linking dotfiles"], @reporter.phases
    refute @reporter.completion_reported
  end

  def test_default_setup_runs_full_setup_without_mapping_confirmation
    source, target = create_mapping("gitconfig")
    brewfile = create_file("dotfiles/Brewfile")
    command_runner = successful_full_command_runner({"brew" => "/opt/homebrew/bin/brew"})
    prompt = TestPrompt.new(true)

    status = build_installer(
      options: {skip_brew: false},
      config: {
        mappings: [mapping(source, target)],
        brewfile_path: brewfile
      },
      runtime: {command_runner: command_runner, prompt: prompt}
    ).install

    assert_equal 0, status
    assert_includes command_runner.calls, ["/opt/homebrew/bin/brew", "bundle", "--file=#{brewfile}"]
    assert_symlink target, to: source
  end

  def test_setup_resolves_dependencies_after_homebrew_establishes_them
    brewfile = create_file("dotfiles/Brewfile")
    plugin_manager_path = tmp_path("home/.local/share/nvim/site/autoload/plug.vim")
    checkout = tmp_path("home/code/opencode")
    executable = tmp_path("home/.local/bin/opencode2")
    executables = {"brew" => "/fake/brew"}
    runner = TestCommandRunner.new(
      executables: executables,
      on_run: lambda do |command, _options|
        case command.first
        when "/fake/brew"
          executables.merge!(
            "pnpm" => "/fake/pnpm",
            "git" => "/fake/git",
            "bun" => "/fake/bun",
            "nvim" => "/fake/nvim",
            "curl" => "/fake/curl"
          )
        when "/fake/pnpm"
          FileUtils.mkdir_p(File.dirname(executable))
          File.write(executable, "#!/bin/sh\n")
          FileUtils.chmod("+x", executable)
        when "/fake/git"
          create_opencode_fork(checkout)
        when "/fake/curl"
          FileUtils.mkdir_p(File.dirname(plugin_manager_path))
          File.write(plugin_manager_path, "vim-plug")
        end
      end
    )

    status = build_installer(
      options: {skip_brew: false, yes: true},
      config: {
        brewfile_path: brewfile,
        nvim_plugin_manager_path: plugin_manager_path,
        opencode_fork_checkout: checkout
      },
      runtime: {command_runner: runner}
    ).install

    assert_equal 0, status
    assert_operator runner.calls.index(["/fake/brew", "bundle", "--file=#{brewfile}"]), :<,
      runner.calls.index { |command| command.first == "/fake/pnpm" }
    assert_includes runner.calls, ["/fake/curl", "-fLo", plugin_manager_path, Phases::Neovim::PLUGIN_MANAGER_URL]
    assert @reporter.completion_reported
  end

  def test_default_dry_run_reports_full_setup_without_execution
    source, target = create_mapping("gitconfig")
    brewfile = create_file("dotfiles/Brewfile")
    command_runner = successful_full_command_runner({"brew" => "/opt/homebrew/bin/brew"})
    prompt = TestPrompt.new { raise "default dry run prompted" }

    status = build_installer(
      options: {skip_brew: false, dry_run: true},
      config: {
        mappings: [mapping(source, target)],
        brewfile_path: brewfile,
        nvim_configuration_targets: []
      },
      runtime: {command_runner: command_runner, prompt: prompt}
    ).install

    assert_equal 0, status
    assert_equal ["Installing Homebrew packages", "Linking dotfiles"], @reporter.phases
    assert_equal :setup, @reporter.workflows.first.fetch(:name)
    assert_equal %i[homebrew opencode2 mappings skills neovim],
      @reporter.workflows.first.fetch(:phases).map(&:first)
    assert_empty command_runner.calls
    refute File.exist?(target)
    assert @reporter.dry_completion_reported
  end

  def test_default_dry_run_reports_neovim_when_mappings_will_create_its_configuration
    targets = %w[init.lua lua/options.lua lua/plugins.lua lua/keymaps.lua lua/autocmds.lua].map do |path|
      tmp_path("home/.config/nvim/#{path}")
    end
    mappings = targets.map.with_index do |target, index|
      mapping(create_file("dotfiles/nvim/#{index}.lua"), target)
    end

    status = build_installer(
      options: {dry_run: true},
      config: {
        mappings: mappings,
        nvim_configuration_targets: targets
      }
    ).install

    assert_equal 0, status
    assert_includes @reporter.workflows.first.fetch(:phases).map(&:first), :neovim
    refute File.exist?(targets.first)
  end

  private

  def build_manifest_installer(repository_root, home_root, manifest_path)
    config = Config.new(
      repository_root: repository_root,
      home_root: home_root,
      mappings_path: manifest_path
    )
    runtime = SetupRuntime.new(reporter: @reporter)
    workflows = {test: {phases: [:mappings], preflight: [:mappings]}}

    Installer.new(
      options: SetupOptions.new(workflow: :test, yes: true),
      prompt: runtime.prompt,
      reporter: runtime.reporter,
      catalog: PhaseCatalog.build(config: config, runtime: runtime, workflows: workflows)
    )
  end

  def build_installer(options: {}, config: {}, runtime: {})
    skip_brew = options.fetch(:skip_brew, true)
    options.delete(:skip_brew)
    selected = Array(options.delete(:only))
    if selected.empty? && !skip_brew
      workflow_name = :setup
      workflows = PhaseCatalog::WORKFLOWS
    else
      selected = %i[opencode2 mappings skills neovim] if selected.empty?
      workflow_name = :test
      workflows = {
        workflow_name => {
          phases: selected,
          preflight: selected
        }
      }
    end
    setup_config = TestConfig.new(
      mappings: config.fetch(:mappings, []),
      brewfile_path: config.fetch(:brewfile_path, "/nonexistent/Brewfile"),
      nvim_configuration_targets: config.fetch(:nvim_configuration_targets, []),
      nvim_plugin_manager_path: config.fetch(:nvim_plugin_manager_path, create_file("installed/plug.vim")),
      opencode2_global_dir: config.fetch(:opencode2_global_dir, tmp_path("home/.local/share/pnpm/global")),
      user_bin_dir: config.fetch(:user_bin_dir, tmp_path("home/.local/bin")),
      opencode_fork_checkout: config.fetch(:opencode_fork_checkout, tmp_path("home/code/opencode")),
      pnpm_candidates: config.fetch(:pnpm_candidates, ["/fake/pnpm"])
    )

    runtime = {command_runner: successful_full_command_runner}.merge(runtime) unless runtime[:command_runner]
    runtime = {prompt: TestPrompt.new}.merge(runtime)
    setup_runtime = SetupRuntime.new(reporter: @reporter, **runtime)
    catalog = PhaseCatalog.build(config: setup_config, runtime: setup_runtime, workflows: workflows)

    Installer.new(
      options: SetupOptions.new(workflow: workflow_name, **options),
      prompt: setup_runtime.prompt,
      reporter: setup_runtime.reporter,
      catalog: catalog
    )
  end

  def successful_full_command_runner(executables = {}, result: true)
    pnpm = "/fake/pnpm"
    git = "/fake/git"
    bun = "/fake/bun"
    bin_dir = tmp_path("home/.local/bin")
    checkout = tmp_path("home/code/opencode")

    TestCommandRunner.new(
      result: result,
      executables: {"pnpm" => pnpm, "git" => git, "bun" => bun, "nvim" => "/fake/nvim"}.merge(executables),
      on_run: lambda do |command, _options|
        if command.first == pnpm
          FileUtils.mkdir_p(bin_dir)
          File.write(File.join(bin_dir, "opencode2"), "#!/bin/sh\n")
          FileUtils.chmod("+x", File.join(bin_dir, "opencode2"))
        elsif command.first == git
          create_opencode_fork(checkout)
        end
      end
    )
  end
end
