# frozen_string_literal: true

require_relative "../config"

module Reporters
  class ConsoleReporter
    class << self
      attr_writer :current

      def current
        @current ||= new
      end

      def with(reporter)
        previous = @current
        @current = reporter
        yield
      ensure
        @current = previous
      end
    end

    PREFIXES = {
      create_directory: "[MKDIR]",
      remove: "[REMOVE]",
      move: "[BACKUP]",
      create_symlink: "[LINK]",
      unchanged: "[OK]",
      neovim_complete: "[OK]"
    }.freeze

    def initialize(output: $stdout)
      @output = output
    end

    def report_phase(name)
      output.puts ""
      output.puts "=== #{name} ==="
      output.puts ""
    end

    def report_workflow(name, phases)
      output.puts ""
      output.puts "=== #{name.to_s.capitalize} workflow ==="
      output.puts ""
      phases.each do |phase, description|
        output.puts "  [PLAN] #{phase}: #{description}"
      end
    end

    def report_action(type, meta = {})
      prefix = PREFIXES.fetch(type, "[???]")
      message = format_action(type, meta)
      output.puts "  #{prefix} #{message}"
    end

    def report_planned(label, message)
      output.puts "  [#{label.to_s.upcase}] #{message}"
    end

    def report_completion(steps = [])
      output.puts ""
      output.puts "Installation complete!"
      output.puts ""
      return if steps.empty?

      output.puts "Next steps:"
      steps.each_with_index do |step, index|
        output.puts "  #{index + 1}. #{step}"
      end
    end

    def report_dry_completion
      output.puts ""
      output.puts "Dry run complete!"
      output.puts ""
      output.puts "Next steps:"
      output.puts "  1. Review the changes above"
      output.puts "  2. Run without --dry-run to apply"
    end

    def report_warning(message)
      output.puts "  [SKIP] #{message}"
    end

    private

    attr_reader :output

    def format_action(type, meta)
      case type
      when :create_directory
        meta[:path]
      when :remove
        meta[:path]
      when :move
        "#{meta[:source]} -> #{meta[:target]}"
      when :create_symlink
        "#{format_path(meta[:source])} -> #{meta[:target]}"
      when :unchanged
        "#{format_path(meta[:source])} -> #{meta[:target]} unchanged"
      when :neovim_complete
        "Neovim plugins installed"
      else
        "#{meta[:name] || meta[:source]} (unknown: #{type})"
      end
    end

    def format_path(path)
      path.to_s.sub(%r{\A#{Regexp.escape(Config::DOTFILES_ROOT)}/}o, "")
    end
  end
end
