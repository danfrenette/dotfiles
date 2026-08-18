# frozen_string_literal: true

require "fileutils"
require_relative "copy_comparison"
require_relative "mapping_manifest"
require_relative "mapping_plan_applier"
require_relative "mapping_planner"

# Creates symlinks from dotfiles to target locations
class Linker
  BACKUP_SUFFIX = MappingManifest::BACKUP_SUFFIX

  def initialize(
    dry_run: false,
    planner: MappingPlanner.new,
    plan_applier: MappingPlanApplier.new
  )
    @dry_run = dry_run
    @planner = planner
    @plan_applier = plan_applier
  end

  def link(source, target)
    source = File.expand_path(source)
    target = File.expand_path(target)

    raise ArgumentError, "Source does not exist: #{source}" unless File.exist?(source)

    execute(source, target)
  end

  def plan(mappings)
    planner.plan(mappings)
  end

  def apply(plan)
    plan_applier.apply(plan)
  end

  def backup(path)
    path = File.expand_path(path)
    return unless File.exist?(path) || File.symlink?(path)

    backup_path = "#{path}#{BACKUP_SUFFIX}"
    FileUtils.rm_rf(backup_path) if File.exist?(backup_path)
    FileUtils.mv(path, backup_path)
    backup_path
  end

  def correctly_linked?(target, source)
    already_linked?(target, source)
  end

  def mapping_current?(mapping)
    return already_linked?(mapping.target, mapping.source) if mapping.link?

    CopyComparison.new(mapping.source, mapping.target).match?
  end

  def current_mapping_targets(mappings)
    mappings.filter_map { |mapping| mapping.target if mapping_current?(mapping) }
  end

  def established_mapping_targets(plan)
    plan.filter_map { |operation| operation.target if operation.establishes_target? }
  end

  private

  attr_reader :dry_run, :planner, :plan_applier

  def execute(source, target)
    action = determine_action(source, target)

    return :already_linked if action == :already_linked
    return :would_replace if dry_run && action == :replace
    return :would_link if dry_run && action == :link

    backup(target) if action == :replace
    create_symlink(source, target)
    :linked
  end

  def determine_action(source, target)
    return :already_linked if already_linked?(target, source)
    return :replace if target_exists?(target)

    :link
  end

  def already_linked?(target, source)
    File.symlink?(target) && File.realpath(target) == File.realpath(source)
  rescue Errno::ENOENT, Errno::ELOOP, Errno::ENOTDIR
    false
  end

  def target_exists?(target)
    File.exist?(target) || File.symlink?(target)
  end

  def create_symlink(source, target)
    target_dir = File.dirname(target)
    FileUtils.mkdir_p(target_dir) unless Dir.exist?(target_dir)
    File.symlink(source, target)
  end
end
