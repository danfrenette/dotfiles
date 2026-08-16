# frozen_string_literal: true

require_relative "copy_comparison"
require_relative "mapping_operation"

class MappingChange
  def initialize(mapping, backup_suffix:)
    @mapping = mapping
    @backup_suffix = backup_suffix
    @source = File.expand_path(mapping.source)
    @target = File.expand_path(mapping.target)
  end

  def operations
    validate_source!
    return [unchanged_operation] if unchanged?

    validate_parent!
    parent_operations + backup_operations + [install_operation]
  end

  private

  attr_reader :mapping, :backup_suffix, :source, :target

  def validate_source!
    exists = File.exist?(source) || (mapping.operation == :copy && File.symlink?(source))
    raise ArgumentError, "Source does not exist: #{source}" unless exists
  end

  def unchanged?
    if mapping.operation == :link
      correctly_linked?
    else
      CopyComparison.new(source, target).match?
    end
  end

  def unchanged_operation
    if mapping.operation == :link
      MappingOperation.unchanged(source, target)
    else
      MappingOperation.unchanged_copy(source, target)
    end
  end

  def parent_operations
    return [] if Dir.exist?(target_directory)

    [MappingOperation.create_directory(target_directory)]
  end

  def backup_operations
    return [] unless target_exists?(target)

    operations = []
    operations << MappingOperation.remove(backup_path) if target_exists?(backup_path)
    operations << MappingOperation.move(target, backup_path)
  end

  def install_operation
    if mapping.operation == :link
      MappingOperation.create_symlink(source, target)
    else
      MappingOperation.create_copy(source, target)
    end
  end

  def correctly_linked?
    File.symlink?(target) && File.realpath(target) == File.realpath(source)
  rescue Errno::ENOENT, Errno::ELOOP, Errno::ENOTDIR
    false
  end

  def validate_parent!
    path = target_directory
    until Dir.exist?(path)
      raise ArgumentError, "Cannot create parent directory: #{path}" if target_exists?(path)

      parent = File.dirname(path)
      return if parent == path

      path = parent
    end
  end

  def target_exists?(path)
    File.exist?(path) || File.symlink?(path)
  end

  def target_directory
    @target_directory ||= File.dirname(target)
  end

  def backup_path
    @backup_path ||= "#{target}#{backup_suffix}"
  end
end
