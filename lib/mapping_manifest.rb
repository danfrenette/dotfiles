# frozen_string_literal: true

require "pathname"
require "yaml"

class MappingManifest
  include Enumerable

  Mapping = Data.define(:operation, :source, :target)
  InvalidManifest = Class.new(ArgumentError)
  OPERATIONS = %w[link copy].freeze

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
    in {operation: String => operation, source: String => source, target: String => target, **nil}
      validate_operation!(operation, index)
      validate_path!(source, :source, index)
      validate_path!(target, :target, index)
      Mapping.new(
        operation: operation.to_sym,
        source: File.join(repository_root, source),
        target: File.join(home_root, target)
      )
    else
      raise InvalidManifest, "mapping #{index + 1} must contain exactly operation, source, and target strings"
    end
  end

  def validate_operation!(operation, index)
    return if OPERATIONS.include?(operation)

    raise InvalidManifest, "mapping #{index + 1} has unsupported operation: #{operation.inspect}"
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
    missing = entries.filter_map do |mapping|
      mapping.source unless source_exists?(mapping)
    end
    return if missing.empty?

    raise InvalidManifest, "mapping sources do not exist: #{missing.join(", ")}"
  end

  def source_exists?(mapping)
    File.exist?(mapping.source) || (mapping.operation == :copy && File.symlink?(mapping.source))
  end

  def path_exists?(path)
    File.exist?(path) || File.symlink?(path)
  end
end
