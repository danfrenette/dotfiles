# frozen_string_literal: true

require_relative "mapping_operation"

class MappingChange
  def initialize(mapping)
    @mapping = mapping
    @source = File.expand_path(mapping.source)
    @target = File.expand_path(mapping.target)
  end

  def operations
    validate_source!
    return [MappingOperation.unchanged(source, target)] if correctly_linked?

    validate_parent!
    parent_operations + backup_operations + [MappingOperation.create_symlink(source, target)]
  end

  private

  attr_reader :mapping, :source, :target

  def validate_source!
    raise ArgumentError, "Source does not exist: #{source}" unless File.exist?(source)
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
    mapping.backup_target
  end
end
