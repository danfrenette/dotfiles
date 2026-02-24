# frozen_string_literal: true

class LinkPlan
  attr_reader :source, :target

  def initialize(source:, target:)
    @source = File.expand_path(source)
    @target = File.expand_path(target)
  end

  def source_exists?
    File.exist?(source)
  end

  def already_linked?
    File.symlink?(target) && File.readlink(target) == source
  end

  def existing_target?
    File.exist?(target) || File.symlink?(target)
  end

  def action
    return :already_linked if already_linked?
    return :replace if existing_target?

    :link
  end
end
