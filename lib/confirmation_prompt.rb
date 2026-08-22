# frozen_string_literal: true

class ConfirmationPrompt
  def initialize(input: $stdin, output: $stdout)
    @input = input
    @output = output
  end

  def confirm?
    output.print "Apply this plan? [y/N] "
    answer = input.gets
    !answer.nil? && %w[y yes].include?(answer.strip.downcase)
  end

  private

  attr_reader :input, :output
end
