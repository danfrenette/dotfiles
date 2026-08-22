# frozen_string_literal: true

require "pathname"
require "yaml"

class MappingManifest
  include Enumerable

  BACKUP_SUFFIX = ".backup"
  Mapping = Data.define(:source, :target) do
    def backup_target
      "#{target}#{MappingManifest::BACKUP_SUFFIX}"
    end
  end
  InvalidManifest = Class.new(ArgumentError)

  def self.load(path, repository_root:, home_root:)
    new(path, repository_root: repository_root, home_root: home_root)
  end

  def each(&block)
    entries.each(&block)
  end

  private

  attr_reader :entries, :repository_root, :home_root

  def initialize(path, repository_root:, home_root:)
    @repository_root = File.expand_path(repository_root)
    @home_root = File.expand_path(home_root)
    @entries = parse(path).each_with_index.map { |entry, index| build_mapping(entry, index) }
    validate_targets!
    validate_sources!
    @entries.freeze
    freeze
  end

  def parse(path)
    case YAML.safe_load_file(path, symbolize_names: true)
    in {mappings: Array => mappings, **nil}
      mappings
    else
      raise InvalidManifest, "manifest must contain only a mappings array"
    end
  end

  def build_mapping(entry, index)
    case entry
    in {source: String => source, target: String => target, **nil}
      validate_path!(source, :source, index)
      validate_path!(target, :target, index)
      Mapping.new(
        source: File.join(repository_root, source),
        target: File.join(home_root, target)
      )
    else
      raise InvalidManifest, "mapping #{index + 1} must contain exactly source and target strings"
    end
  end

  def validate_path!(path, field, index)
    components = path.split("/", -1)
    return unless path.empty? || path.start_with?("~") || Pathname.new(path).absolute? ||
      components.any? { |component| component.empty? || component == "." || component == ".." }

    raise InvalidManifest,
      "mapping #{index + 1} #{field} must be a non-empty relative path without . or .. components"
  end

  def validate_targets!
    entries.each_with_index do |mapping, index|
      overlap = entries[0...index].find { |other| overlapping?(mapping.target, other.target) }
      if overlap
        raise InvalidManifest, "mapping targets overlap: #{overlap.target} and #{mapping.target}"
      end

      validate_target_parent!(mapping.target)
    end

    entries.each do |mapping|
      collision = entries.find { |other| overlapping?(mapping.backup_target, other.target) }
      if collision
        raise InvalidManifest,
          "mapping backup path overlaps mapping target: #{mapping.backup_target} and #{collision.target}"
      end
    end
  end

  def overlapping?(first, second)
    first == second || first.start_with?("#{second}/") || second.start_with?("#{first}/")
  end

  def validate_target_parent!(target)
    parent = File.dirname(target)
    parent = File.dirname(parent) until path_exists?(parent) || File.dirname(parent) == parent
    resolved_parent = File.realpath(parent)
    resolved_home = File.realpath(home_root)
    return if resolved_parent == resolved_home || resolved_parent.start_with?("#{resolved_home}/")

    raise InvalidManifest, "mapping target parent escapes home root: #{target}"
  rescue Errno::ENOENT, Errno::ELOOP, Errno::ENOTDIR
    raise InvalidManifest, "mapping target parent cannot be resolved safely: #{target}"
  end

  def validate_sources!
    missing = entries.filter_map { |mapping| mapping.source unless File.exist?(mapping.source) }
    unless missing.empty?
      raise InvalidManifest, "mapping sources do not exist: #{missing.join(", ")}"
    end

    entries.each { |mapping| validate_source_parent!(mapping.source) }
  end

  def validate_source_parent!(source)
    resolved_parent = File.realpath(File.dirname(source))
    resolved_repository = File.realpath(repository_root)
    return if resolved_parent == resolved_repository || resolved_parent.start_with?("#{resolved_repository}/")

    raise InvalidManifest, "mapping source parent escapes repository root: #{source}"
  rescue Errno::ENOENT, Errno::ELOOP, Errno::ENOTDIR
    raise InvalidManifest, "mapping source parent cannot be resolved safely: #{source}"
  end

  def path_exists?(path)
    File.exist?(path) || File.symlink?(path)
  end
end
