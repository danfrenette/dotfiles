# frozen_string_literal: true

class TestCommandRunner
  attr_reader :calls

  def initialize(result: true)
    @result = result
    @calls = []
  end

  def call(*command, **options)
    calls << (options.empty? ? command : [*command, options])
    result
  end

  private

  attr_reader :result
end
