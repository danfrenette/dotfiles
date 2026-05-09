# frozen_string_literal: true

require "fileutils"
require_relative "config"
require_relative "linker"

# Installs agent skills from the repo-wide skills directory.
class SkillInstaller
  EXCLUDED_PATH_PARTS = %w[node_modules deprecated].freeze

  def initialize(output: $stdout, dry_run: false, config: Config.new, linker: nil)
    @output = output
    @dry_run = dry_run
    @config = config
    @linker = linker || Linker.new(dry_run: dry_run)
  end

  def install
    guard_against_recursive_destination

    skills = skill_sources
    if skills.empty?
      log "  [SKIP] no skills found in #{config.skills_source_root}"
      return
    end

    skills.each do |name, source|
      target = File.join(config.opencode_skills_target, name)
      result = linker.link(source, target)
      log_skill_result(name, source, target, result)
    end
  end

  def skill_sources
    pattern = File.join(config.skills_source_root, "**", "SKILL.md")

    Dir.glob(pattern).sort.each_with_object({}) do |skill_file, skills|
      next if excluded_path?(skill_file)

      source = File.dirname(skill_file)
      skills[File.basename(source)] = source
    end
  end

  private

  attr_reader :output, :dry_run, :config, :linker

  def excluded_path?(path)
    path.split(File::SEPARATOR).any? { |part| EXCLUDED_PATH_PARTS.include?(part) }
  end

  def guard_against_recursive_destination
    return unless File.symlink?(config.opencode_skills_target)

    destination = File.realpath(config.opencode_skills_target)
    source_root = File.realpath(config.skills_source_root)
    return unless destination == source_root || destination.start_with?("#{source_root}/")

    raise "#{config.opencode_skills_target} is a symlink into this repo (#{destination})"
  rescue Errno::ENOENT
    nil
  end

  def log_skill_result(name, source, target, result)
    source_label = source.sub("#{Config::DOTFILES_ROOT}/", "")

    case result
    when :linked
      log "  [LINK] #{name} -> #{target}"
    when :already_linked
      log "  [OK]   #{name}"
    when :would_link
      log "  [DRY]  #{source_label} would link to #{target}"
    when :would_replace
      log "  [DRY]  #{source_label} would back up #{target} -> #{target}.backup"
      log "  [DRY]  #{source_label} would replace #{target}"
    else
      log "  [???]  #{source_label} (unknown result: #{result})"
    end
  end

  def log(message)
    output.puts message
  end
end
