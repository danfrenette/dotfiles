# frozen_string_literal: true

class TestPrompt
  def initialize(answer = true, &behavior)
    @answer = answer
    @behavior = behavior
  end

  def confirm?
    return behavior.call if behavior

    answer
  end

  def select(phases)
    phases
  end

  private

  attr_reader :answer, :behavior
end
