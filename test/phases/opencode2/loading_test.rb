# frozen_string_literal: true

require "test_helper"
require "open3"
require "rbconfig"

class OpenCode2LoadingTest < DotfilesTestCase
  def test_dedicated_modules_are_independently_loadable
    %w[
      phases/opencode2/cli_installation
      phases/opencode2/fork_workspace
      phases/opencode2/phase
    ].each do |path|
      _output, error, status = Open3.capture3(
        RbConfig.ruby,
        "-Ilib",
        "-e",
        "require '#{path}'; Phases::OpenCode2::Error",
        chdir: File.expand_path("../../..", __dir__)
      )

      assert status.success?, "#{path} failed to load: #{error}"
    end
  end
end
