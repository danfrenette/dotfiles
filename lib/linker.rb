# frozen_string_literal: true

require "fileutils"

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
    mappings.flat_map do |source, target|
      source = File.expand_path(source)
      target = File.expand_path(target)
      raise ArgumentError, "Source does not exist: #{source}" unless File.exist?(source)
      if already_linked?(target, source)
        next [{type: :unchanged, source: source, target: target}]
      end

      operations = []
      target_dir = File.dirname(target)
      validate_parent(target_dir)
      operations << {type: :create_directory, path: target_dir} unless Dir.exist?(target_dir)
      if target_exists?(target)
        backup_path = "#{target}#{BACKUP_SUFFIX}"
        operations << {type: :remove, path: backup_path} if target_exists?(backup_path)
        operations << {type: :move, source: target, target: backup_path}
      end
      operations << {type: :create_symlink, source: source, target: target}
      operations
    end
  end

  def apply(plan)
    plan.each do |operation|
      case operation.fetch(:type)
      when :create_directory
        FileUtils.mkdir_p(operation.fetch(:path))
      when :create_symlink
        File.symlink(operation.fetch(:source), operation.fetch(:target))
      when :move
        FileUtils.mv(operation.fetch(:source), operation.fetch(:target))
      when :remove
        FileUtils.rm_rf(operation.fetch(:path))
      when :unchanged
        nil
      else
        raise ArgumentError, "Unknown link operation: #{operation.fetch(:type)}"
      end
    end
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
    File.symlink?(target) && File.readlink(target) == source
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
