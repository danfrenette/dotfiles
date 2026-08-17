# frozen_string_literal: true

require "test_helper"
require "command_runner"

class CommandRunnerTest < DotfilesTestCase
  def test_finds_executable_on_path
    executable = create_executable("path/bin/brew")

    with_path(File.dirname(executable)) do
      assert_equal executable, CommandRunner.new.find_executable("brew")
    end
  end

  def test_falls_back_to_candidate
    candidate = create_executable("candidate/brew")

    with_path(create_dir("empty-bin")) do
      assert_equal candidate, CommandRunner.new.find_executable("brew", candidates: [candidate])
    end
  end

  def test_path_takes_precedence_over_candidate
    path_executable = create_executable("path/bin/brew")
    candidate = create_executable("candidate/brew")

    with_path(File.dirname(path_executable)) do
      assert_equal path_executable, CommandRunner.new.find_executable("brew", candidates: [candidate])
    end
  end

  def test_rejects_non_files_and_non_executable_files
    path_directory = create_dir("path-bin")
    create_file("path-bin/brew")
    directory = create_dir("candidate-directory")
    non_executable = create_file("candidate-file")

    with_path(path_directory) do
      assert_nil CommandRunner.new.find_executable("brew", candidates: [directory, non_executable])
    end
  end

  def test_returns_nil_when_executable_is_not_found
    with_path(create_dir("empty-bin")) do
      assert_nil CommandRunner.new.find_executable("brew", candidates: [tmp_path("missing-brew")])
    end
  end

  def test_empty_path_entry_searches_current_directory
    executable = create_executable("work/brew")

    Dir.chdir(File.dirname(executable)) do
      with_path("") do
        assert_equal File.realpath(executable), CommandRunner.new.find_executable("brew")
      end
    end
  end

  def test_can_restrict_executable_search_to_durable_candidates
    path_executable = create_executable("nvm/bin/pnpm")
    candidate = create_executable("homebrew/bin/pnpm")

    with_path(File.dirname(path_executable)) do
      assert_equal candidate,
        CommandRunner.new.find_executable("pnpm", candidates: [candidate], search_path: false)
    end
  end

  def test_run_propagates_environment
    output = tmp_path("environment.txt")
    executable = create_file("bin/write-environment", <<~SH)
      #!/bin/sh
      printf %s "$COMMAND_RUNNER_VALUE" > "$1"
    SH
    FileUtils.chmod("+x", executable)

    assert CommandRunner.new.run(executable, output, env: {"COMMAND_RUNNER_VALUE" => "propagated"})
    assert_equal "propagated", File.read(output)
  end

  def test_capture_returns_successful_output
    executable = create_file("bin/capture-success", "#!/bin/sh\nprintf 'captured output'")
    FileUtils.chmod("+x", executable)

    assert_equal "captured output", CommandRunner.new.capture(executable)
  end

  def test_capture_returns_nil_for_nonzero_exit
    executable = create_file("bin/capture-failure", "#!/bin/sh\nexit 42\n")
    FileUtils.chmod("+x", executable)

    assert_nil CommandRunner.new.capture(executable)
  end

  def test_capture_returns_nil_when_command_cannot_start
    assert_nil CommandRunner.new.capture(tmp_path("missing-command"))
  end

  private

  def create_executable(path)
    create_file(path, "#!/bin/sh\n").tap { |file| FileUtils.chmod("+x", file) }
  end

  def with_path(path)
    original_path = ENV["PATH"]
    ENV["PATH"] = path
    yield
  ensure
    ENV["PATH"] = original_path
  end
end
