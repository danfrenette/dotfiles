# frozen_string_literal: true

require "fileutils"

class CopyComparison
  PERMISSION_BITS_MASK = 0o7777

  def initialize(source, target)
    @source = source
    @target = target
  end

  def match?
    return false unless target_exists?
    return false unless source_stat.ftype == target_stat.ftype
    return false unless modes_match?

    contents_match?
  rescue Errno::ENOENT, Errno::ELOOP, Errno::ENOTDIR
    false
  end

  private

  attr_reader :source, :target

  def source_stat
    @source_stat ||= File.lstat(source)
  end

  def target_stat
    @target_stat ||= File.lstat(target)
  end

  def modes_match?
    (source_stat.mode & PERMISSION_BITS_MASK) == (target_stat.mode & PERMISSION_BITS_MASK)
  end

  def contents_match?
    case source_stat.ftype
    when "link"
      File.readlink(source) == File.readlink(target)
    when "file"
      FileUtils.compare_file(source, target)
    when "directory"
      directory_contents_match?
    else
      false
    end
  end

  def directory_contents_match?
    source_entries = Dir.children(source).sort
    target_entries = Dir.children(target).sort
    source_entries == target_entries && source_entries.all? do |entry|
      CopyComparison.new(File.join(source, entry), File.join(target, entry)).match?
    end
  end

  def target_exists?
    File.exist?(target) || File.symlink?(target)
  end
end
