# frozen_string_literal: true

class TestPrompt
  def initialize(answer = nil, &behavior)
    @answer = answer
    @behavior = behavior
  end

  def confirm?
    return behavior.call if behavior

    answer
  end

  private

  attr_reader :answer, :behavior
end
