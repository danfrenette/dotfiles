# frozen_string_literal: true

require_relative "confirmation_prompt"
require_relative "command_runner"
require_relative "reporters/console_reporter"

class SetupRuntime
  attr_reader :reporter, :prompt, :command_runner

  def initialize(
    reporter: Reporters::ConsoleReporter.new,
    prompt: ConfirmationPrompt.new,
    command_runner: CommandRunner.new
  )
    @reporter = reporter
    @prompt = prompt
    @command_runner = command_runner
  end
end
