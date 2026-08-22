# frozen_string_literal: true

require "optparse"
require_relative "installer"

class SetupCLI
  def initialize(arguments, output: $stdout, error: $stderr)
    @arguments = arguments.dup
    @output = output
    @error = error
    @help = false
    @options = {}
  end

  def run
    parser = option_parser
    command = arguments.shift unless arguments.first&.start_with?("-")
    parser.parse!(arguments)

    if help
      output.puts parser
      return 0
    end

    raise OptionParser::MissingArgument, "COMMAND must be setup or refresh" unless command

    unless %w[setup refresh].include?(command)
      raise OptionParser::InvalidArgument, "unknown command: #{command}"
    end

    validate_arguments
    Installer.run(options: SetupOptions.new(workflow: command.to_sym, **options))
  rescue OptionParser::ParseError, PhaseCatalog::UnsupportedPhase, ArgumentError => parse_error
    error.puts parse_error.message
    error.puts parser
    64
  end

  private

  attr_reader :arguments, :output, :error, :help, :options

  def option_parser
    OptionParser.new do |parser|
      parser.banner = <<~USAGE
        Usage: install.rb COMMAND [options]

        Commands:
            setup                         Set up a new machine
            refresh                       Update dotfiles and skills
      USAGE
      parser.on("--dry-run", "Print the plan without applying it") { options[:dry_run] = true }
      parser.on("--yes", "Apply the plan without confirmation") { options[:yes] = true }
      parser.on("-h", "--help", "Show this help") { @help = true }
    end
  end

  def validate_arguments
    return if arguments.empty?

    raise ArgumentError, "Unexpected arguments: #{arguments.join(" ")}"
  end
end
