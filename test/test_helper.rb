# frozen_string_literal: true

require "minitest/autorun"
require "fileutils"
require "tmpdir"
require "stringio"
require "yaml"

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require "linker"
require "config"
require "support/assertions"
require "support/skill_fixtures"
require "support/test_config"
require "support/test_prompt"
require "support/test_command_runner"
require "support/mapping_fixtures"

class DotfilesTestCase < Minitest::Test
  include Assertions
  include SkillFixtures
  include MappingFixtures

  def setup
    @tmpdir = Dir.mktmpdir("dotfiles-test")
  end

  def teardown
    FileUtils.rm_rf(@tmpdir) if @tmpdir && Dir.exist?(@tmpdir)
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
