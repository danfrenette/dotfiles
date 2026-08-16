# frozen_string_literal: true

require "fileutils"
require_relative "mapping_operation"

class MappingPlanner
  def initialize(backup_suffix:)
    @backup_suffix = backup_suffix
  end

  def plan(mappings)
    mappings.flat_map { |mapping| plan_mapping(mapping) }
  end

  private

  attr_reader :backup_suffix

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
      backup_path = "#{target}#{backup_suffix}"
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
end
