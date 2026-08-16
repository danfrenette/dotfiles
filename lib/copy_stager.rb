# frozen_string_literal: true

require "fileutils"
require "tmpdir"

class CopyStager
  StagedCopy = Data.define(:directory, :path)

  class StagedCopies
    def initialize(entries)
      @entries = entries.freeze
      freeze
    end

    def path_for(operation)
      entries.fetch(operation).path
    end

    private

    attr_reader :entries
  end

  def stage(plan)
    staged = {}
    created_directories = []

    begin
      plan.select(&:copy?).each do |operation|
        parent = File.dirname(operation.target)
        created_directories.concat(missing_directories(parent))
        FileUtils.mkdir_p(parent)
        directory = Dir.mktmpdir(".dotfiles-stage-", parent)
        path = File.join(directory, "content")
        staged[operation] = StagedCopy.new(directory: directory, path: path)
        FileUtils.copy_entry(operation.source, path, true, false)
      end
    rescue
      clean_staging(staged)
      remove_created_directories(created_directories)
      raise
    end

    begin
      yield StagedCopies.new(staged)
    ensure
      clean_staging(staged)
    end
  end

  private

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

  def clean_staging(staged)
    staged.each_value { |copy| FileUtils.rm_rf(copy.directory) }
  end

  def remove_created_directories(directories)
    directories.reverse_each do |directory|
      Dir.rmdir(directory)
    rescue Errno::ENOENT, Errno::ENOTDIR, Errno::ENOTEMPTY
      nil
    end
  end
end
