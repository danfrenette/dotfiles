# frozen_string_literal: true

require "fileutils"
require_relative "link_plan"

# Creates symlinks from dotfiles to target locations
class Linker
  BACKUP_SUFFIX = ".backup"

  def initialize(dry_run: false)
    @dry_run = dry_run
  end

  def link(source, target)
    plan = LinkPlan.new(source: source, target: target)

    raise ArgumentError, "Source does not exist: #{plan.source}" unless plan.source_exists?

    execute_plan(plan)
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
    File.symlink?(target) && File.readlink(target) == source
  end

  private

  attr_reader :dry_run

  def execute_plan(plan)
    return :already_linked if plan.action == :already_linked
    return :would_replace if dry_run && plan.action == :replace
    return :would_link if dry_run && plan.action == :link

    backup(plan.target) if plan.action == :replace
    create_symlink(plan.source, plan.target)
    :linked
  end

  def create_symlink(source, target)
    target_dir = File.dirname(target)
    FileUtils.mkdir_p(target_dir) unless Dir.exist?(target_dir)
    File.symlink(source, target)
  end
end
