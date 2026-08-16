# frozen_string_literal: true

require "fileutils"
require "tmpdir"
require_relative "mapping_operation"

# Creates symlinks from dotfiles to target locations
class Linker
  BACKUP_SUFFIX = ".backup"

  def initialize(dry_run: false)
    @dry_run = dry_run
  end

  def link(source, target)
    source = File.expand_path(source)
    target = File.expand_path(target)

    raise ArgumentError, "Source does not exist: #{source}" unless File.exist?(source)

    execute(source, target)
  end

  def plan(mappings)
    mappings.flat_map { |mapping| plan_mapping(mapping) }
  end

  def apply(plan)
    staged_copies = stage_copies(plan)

    plan.each do |operation|
      case operation.type
      when :create_directory
        FileUtils.mkdir_p(operation.path)
      when :create_symlink
        File.symlink(operation.source, operation.target)
      when :create_copy
        File.rename(staged_copies.fetch(operation).staged_path, operation.target)
      when :move
        FileUtils.mv(operation.source, operation.target)
      when :remove
        FileUtils.rm_rf(operation.path)
      when :unchanged, :unchanged_copy
        nil
      end
    end
  ensure
    staged_copies&.each_value { |staged| FileUtils.rm_rf(staged.directory) }
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

  private

  attr_reader :dry_run

  StagedCopy = Data.define(:directory, :staged_path)

  def plan_mapping(mapping)
    source = File.expand_path(mapping.source)
    target = File.expand_path(mapping.target)
    validate_source!(mapping.operation, source)

    unchanged = if mapping.operation == :link
      already_linked?(target, source)
    else
      copies_match?(source, target)
    end
    if unchanged
      operation = if mapping.operation == :link
        MappingOperation.unchanged(source, target)
      else
        MappingOperation.unchanged_copy(source, target)
      end
      return [operation]
    end

    operations = []
    target_dir = File.dirname(target)
    validate_parent(target_dir)
    operations << MappingOperation.create_directory(target_dir) unless Dir.exist?(target_dir)
    if target_exists?(target)
      backup_path = "#{target}#{BACKUP_SUFFIX}"
      operations << MappingOperation.remove(backup_path) if target_exists?(backup_path)
      operations << MappingOperation.move(target, backup_path)
    end
    operations << if mapping.operation == :link
      MappingOperation.create_symlink(source, target)
    else
      MappingOperation.create_copy(source, target)
    end
  end

  def validate_source!(operation, source)
    exists = File.exist?(source) || (operation == :copy && File.symlink?(source))
    raise ArgumentError, "Source does not exist: #{source}" unless exists
  end

  def stage_copies(plan)
    staged = {}
    created_directories = []

    plan.select(&:copy?).each do |operation|
      parent = File.dirname(operation.target)
      created_directories.concat(missing_directories(parent))
      FileUtils.mkdir_p(parent)
      directory = Dir.mktmpdir(".dotfiles-stage-", parent)
      staged_path = File.join(directory, "content")
      staged[operation] = StagedCopy.new(directory: directory, staged_path: staged_path)
      FileUtils.copy_entry(operation.source, staged_path, true, false)
    end
    staged
  rescue
    staged.each_value { |copy| FileUtils.rm_rf(copy.directory) }
    created_directories.reverse_each do |directory|
      Dir.rmdir(directory)
    rescue Errno::ENOENT, Errno::ENOTEMPTY
      nil
    end
    raise
  end

  def missing_directories(path)
    directories = []
    until Dir.exist?(path)
      directories << path
      parent = File.dirname(path)
      break if parent == path

      path = parent
    end
    directories.reverse
  end

  def copies_match?(source, target)
    return false unless target_exists?(target)

    source_stat = File.lstat(source)
    target_stat = File.lstat(target)
    return false unless same_type?(source_stat, target_stat)
    return false unless (source_stat.mode & 0o7777) == (target_stat.mode & 0o7777)

    if source_stat.symlink?
      File.readlink(source) == File.readlink(target)
    elsif source_stat.file?
      FileUtils.compare_file(source, target)
    elsif source_stat.directory?
      source_entries = Dir.children(source).sort
      target_entries = Dir.children(target).sort
      source_entries == target_entries && source_entries.all? do |entry|
        copies_match?(File.join(source, entry), File.join(target, entry))
      end
    else
      false
    end
  rescue Errno::ENOENT, Errno::ELOOP, Errno::ENOTDIR
    false
  end

  def same_type?(first, second)
    %i[file directory symlink].any? { |type| first.public_send("#{type}?") && second.public_send("#{type}?") }
  end

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

  def validate_parent(path)
    until Dir.exist?(path)
      raise ArgumentError, "Cannot create parent directory: #{path}" if target_exists?(path)

      parent = File.dirname(path)
      return if parent == path

      path = parent
    end
  end

  def create_symlink(source, target)
    target_dir = File.dirname(target)
    FileUtils.mkdir_p(target_dir) unless Dir.exist?(target_dir)
    File.symlink(source, target)
  end
end
