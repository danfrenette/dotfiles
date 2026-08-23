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
    COLORS = {
      blue: 34,
      cyan: 36,
      green: 32,
      red: 31,
      yellow: 33
    }.freeze

    def initialize(output: $stdout)
      @output = output
    end

    def report_phase(name)
      output.puts ""
      output.puts color("=== #{name} ===", :cyan)
      output.puts ""
    end

    def report_workflow(name, phases)
      output.puts ""
      output.puts color("=== #{name.to_s.capitalize} workflow ===", :blue)
      output.puts ""
      phases.each do |phase, description|
        output.puts "  #{color("[PLAN]", :blue)} #{phase}: #{description}"
      end
    end

    def report_action(type, meta = {})
      prefix = PREFIXES.fetch(type, "[???]")
      message = format_action(type, meta)
      output.puts "  #{color(prefix, color_for(type))} #{message}"
    end

    def report_planned(label, message)
      output.puts "  #{color("[#{label.to_s.upcase}]", :yellow)} #{message}"
    end

    def report_completion(steps = [])
      output.puts ""
      output.puts color("Installation complete!", :green)
      output.puts ""
      return if steps.empty?

      output.puts color("Next steps:", :cyan)
      steps.each_with_index do |step, index|
        output.puts "  #{index + 1}. #{step}"
      end
    end

    def report_dry_completion
      output.puts ""
      output.puts color("Dry run complete!", :yellow)
      output.puts ""
      output.puts color("Next steps:", :cyan)
      output.puts "  1. Review the changes above"
      output.puts "  2. Run without --dry-run to apply"
    end

    def report_warning(message)
      first, *rest = message.lines(chomp: true)
      output.puts "  #{color("[SKIP]", :red)} #{first}"
      rest.each { |line| output.puts "         #{line}" }
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

    def color_for(type)
      case type
      when :create_directory, :create_symlink, :neovim_complete
        :green
      when :move
        :yellow
      when :remove
        :red
      when :unchanged
        :cyan
      else
        :red
      end
    end

    def color(text, name)
      return text unless output.tty? && !ENV.key?("NO_COLOR")

      "\e[#{COLORS.fetch(name)}m#{text}\e[0m"
    end

    def format_path(path)
      path.to_s.sub(%r{\A#{Regexp.escape(Config::DOTFILES_ROOT)}/}o, "")
    end
  end
end
