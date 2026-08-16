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
    parser.parse!(arguments)

    if help
      output.puts parser
      return 0
    end

    validate_arguments
    Installer.new(options: SetupOptions.new(**options)).install
  rescue OptionParser::ParseError, ArgumentError => parse_error
    error.puts parse_error.message
    error.puts parser
    64
  end

  private

  attr_reader :arguments, :output, :error, :help, :options

  def option_parser
    OptionParser.new do |parser|
      parser.banner = "Usage: install.rb [options]"
      parser.on("--dry-run", "Print the plan without applying it") { options[:dry_run] = true }
      parser.on("--yes", "Apply mappings without confirmation") { options[:yes] = true }
      parser.on("--only PHASE", "Run only one setup phase") { |phase| options[:only] = phase.to_sym }
      parser.on("--skip-brew", "Skip the Homebrew phase") { options[:skip_brew] = true }
      parser.on("--skills-only", "Install skills only") { options[:skills_only] = true }
      parser.on("-h", "--help", "Show this help") { @help = true }
    end
  end

  def validate_arguments
    return if arguments.empty?

    raise ArgumentError, "Unexpected arguments: #{arguments.join(" ")}"
  end
end
