# frozen_string_literal: true

require "minitest/autorun"
require "fileutils"
require "tmpdir"
require "stringio"
require "yaml"

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require "config"
require "phases/mappings"
require "reporters/console_reporter"
require "support/assertions"
require "support/test_config"
require "support/test_prompt"
require "support/test_command_runner"
require "support/test_reporter"
require "support/mapping_fixtures"
require "support/opencode_fixtures"

class DotfilesTestCase < Minitest::Test
  include Assertions
  include MappingFixtures
  include OpenCodeFixtures

  def setup
    @tmpdir = Dir.mktmpdir("dotfiles-test")
  end

  def teardown
    Reporters::ConsoleReporter.current = @previous_reporter if defined?(@previous_reporter)
    FileUtils.rm_rf(@tmpdir) if @tmpdir && Dir.exist?(@tmpdir)
  end

  def use_reporter(reporter)
    @previous_reporter = Reporters::ConsoleReporter.current unless defined?(@previous_reporter)
    Reporters::ConsoleReporter.current = reporter
  end

  def tmp_path(*parts)
    File.join(@tmpdir, *parts)
  end

  def create_file(path, content = "test content")
    full_path = path.start_with?("/") ? path : tmp_path(path)
    FileUtils.mkdir_p(File.dirname(full_path))
    File.write(full_path, content)
    full_path
  end

  def create_dir(path)
    full_path = path.start_with?("/") ? path : tmp_path(path)
    FileUtils.mkdir_p(full_path)
    full_path
  end
end
