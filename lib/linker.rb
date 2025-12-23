# frozen_string_literal: true

require "fileutils"

# Creates symlinks from dotfiles to target locations
class Linker
  BACKUP_SUFFIX = ".backup"

  def link(source, target)
    source = File.expand_path(source)
    target = File.expand_path(target)

    raise ArgumentError, "Source does not exist: #{source}" unless File.exist?(source)

    return :already_linked if correctly_linked?(target, source)

    backup(target) if File.exist?(target) || File.symlink?(target)
    create_symlink(source, target)
    :linked
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

  def create_symlink(source, target)
    target_dir = File.dirname(target)
    FileUtils.mkdir_p(target_dir) unless Dir.exist?(target_dir)
    File.symlink(source, target)
  end
end
