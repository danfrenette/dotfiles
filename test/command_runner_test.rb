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
