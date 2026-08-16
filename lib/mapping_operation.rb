# frozen_string_literal: true

MappingOperation = Data.define(:type, :source, :target, :path) do
  def self.create_directory(path)
    new(type: :create_directory, source: nil, target: nil, path: path)
  end

  def self.remove(path)
    new(type: :remove, source: nil, target: nil, path: path)
  end

  def self.move(source, target)
    new(type: :move, source: source, target: target, path: nil)
  end

  def self.create_symlink(source, target)
    new(type: :create_symlink, source: source, target: target, path: nil)
  end

  def self.create_copy(source, target)
    new(type: :create_copy, source: source, target: target, path: nil)
  end

  def self.unchanged(source, target)
    new(type: :unchanged, source: source, target: target, path: nil)
  end

  def self.unchanged_copy(source, target)
    new(type: :unchanged_copy, source: source, target: target, path: nil)
  end

  def meta
    {source: source, target: target, path: path}.compact
  end

  def copy?
    type == :create_copy
  end
end

class << MappingOperation
  private :new
end
