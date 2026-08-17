# frozen_string_literal: true

require_relative "reporter"

module Reporters
  class ConsoleReporter
    include Reporter

    PREFIXES = {
      linked: "[LINK]",
      already_linked: "[OK]",
      would_link: "[DRY]",
      would_replace: "[DRY]",
      skipped: "[SKIP]",
      create_directory: "[MKDIR]",
      remove: "[REMOVE]",
      move: "[BACKUP]",
      create_symlink: "[LINK]",
      create_copy: "[COPY]",
      unchanged: "[OK]",
      unchanged_copy: "[OK]",
      available: "[OK]",
      package_manager: "[OK]",
      bundle: "[BREW]",
      package: "[PKG]",
      destination: "[DEST]",
      install: "[RUN]",
      verify: "[CHECK]",
      source: "[SOURCE]",
      dependencies: "[DEPS]",
      service: "[SERVICE]",
      workflow: "[READY]",
      neovim: "[NVIM]"
    }.freeze

    def initialize(output: $stdout)
      @output = output
    end

    def report_phase(name)
      output.puts ""
      output.puts "=== #{name} ==="
      output.puts ""
    end

    def report_action(type, meta = {})
      prefix = PREFIXES.fetch(type, "[???]")
      message = format_action(type, meta)
      output.puts "  #{prefix} #{message}"
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
      when :linked
        source = meta[:source] || meta[:name]
        target = meta[:target]
        "#{format_path(source)} -> #{target}"
      when :already_linked
        name = meta[:name] || format_path(meta[:source])
        name.to_s
      when :would_link
        source = meta[:source] || meta[:name]
        target = meta[:target]
        "#{format_path(source)} would link to #{target}"
      when :would_replace
        source = meta[:source] || meta[:name]
        target = meta[:target]
        "#{format_path(source)} would back up #{target} -> #{target}.backup and replace"
      when :skipped
        meta[:message].to_s
      when :create_directory
        meta[:path]
      when :remove
        meta[:path]
      when :move
        "#{meta[:source]} -> #{meta[:target]}"
      when :create_symlink
        "#{format_path(meta[:source])} -> #{meta[:target]}"
      when :create_copy
        "#{format_path(meta[:source])} -> #{meta[:target]}"
      when :unchanged, :unchanged_copy
        "#{format_path(meta[:source])} -> #{meta[:target]} unchanged"
      when :available
        "Homebrew executable: #{meta[:path]}"
      when :package_manager
        "#{meta[:name]} executable: #{meta[:path]}"
      when :bundle
        "#{meta[:command].join(" ")} (#{meta[:effect]})"
      when :package
        "#{meta[:specification]} (prerelease channel: #{meta[:channel]})"
      when :destination
        "#{meta[:executable]} (packages: #{meta[:package_directory]}, binaries: #{meta[:binary_directory]})"
      when :install, :verify
        meta[:command].join(" ")
      when :source, :dependencies
        meta[:command].join(" ")
      when :service
        "#{meta[:command].join(" ")} (#{meta[:effect]})"
      when :workflow
        "#{meta[:command].join(" ")} (#{meta[:effect]})"
      when :neovim
        "#{meta[:command].join(" ")} (configuration: #{meta[:configuration_targets].join(", ")})"
      else
        "#{meta[:name] || meta[:source]} (unknown: #{type})"
      end
    end

    def format_path(path)
      path.to_s.sub(%r{\A#{Regexp.escape(Config::DOTFILES_ROOT)}/}o, "")
    end
  end
end
