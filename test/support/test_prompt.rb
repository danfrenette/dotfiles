# frozen_string_literal: true

class TestPrompt
  attr_reader :confirmations

  def initialize(answer = true, &behavior)
    @answer = answer
    @behavior = behavior
    @confirmations = 0
  end

  def confirm?
    @confirmations += 1
    return behavior.call if behavior

    answer
  end

  def select(phases)
    phases
  end

  private

  attr_reader :answer, :behavior
end
