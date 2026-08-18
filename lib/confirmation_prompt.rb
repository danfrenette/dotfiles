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

  def select(phases)
    phases.select do |phase|
      output.print "Run #{phase}? [Y/n] "
      answer = input.gets
      answer.nil? || !%w[n no].include?(answer.strip.downcase)
    end
  end

  private

  attr_reader :input, :output
end
