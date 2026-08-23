# frozen_string_literal: true

class TestCommandRunner
  attr_reader :calls, :capture_calls

  def initialize(result: true, results: nil, executables: {}, captures: {}, on_run: nil)
    @result = result
    @results = results&.dup
    @executables = executables
    @captures = {
      "brew" => "ready\n",
      "bun" => "1.3.14\n",
      "xcode-select" => "/Applications/Xcode.app/Contents/Developer\n",
      "xcodebuild" => "ready\n"
    }.merge(captures)
    @on_run = on_run
    @calls = []
    @capture_calls = []
  end

  def find_executable(name, candidates: [], search_path: true)
    executables[name]
  end

  def run(*command, env: {}, **options)
    invocation_options = options.merge(env.empty? ? {} : {env: env})
    calls << (invocation_options.empty? ? command : [*command, invocation_options])
    on_run&.call(command, options)
    results ? results.shift : result
  end

  def capture(*command)
    capture_calls << command
    captures[File.basename(command.first)]
  end

  private

  attr_reader :captures, :executables, :on_run, :result, :results
end
