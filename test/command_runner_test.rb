# frozen_string_literal: true

require "test_helper"
require "command_runner"

class CommandRunnerTest < DotfilesTestCase
  def test_empty_path_entry_searches_current_directory
    executable = create_file("work/brew", "#!/bin/sh\n")
    FileUtils.chmod("+x", executable)
    original_path = ENV["PATH"]

    Dir.chdir(File.dirname(executable)) do
      ENV["PATH"] = ""
      assert_equal File.realpath(executable), CommandRunner.new.find_executable("brew")
    end
  ensure
    ENV["PATH"] = original_path
  end
end
