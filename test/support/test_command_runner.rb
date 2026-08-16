# frozen_string_literal: true

class TestCommandRunner
  attr_reader :calls

  def initialize(result: true, executables: {})
    @result = result
    @executables = executables
    @calls = []
  end

  def find_executable(name, candidates: [])
    executables[name]
  end

  def run(*command, **options)
    calls << (options.empty? ? command : [*command, options])
    result
  end

  private

  attr_reader :executables, :result
end
