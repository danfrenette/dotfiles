# frozen_string_literal: true

require "fileutils"
require_relative "copy_stager"

class MappingPlanApplier
  def initialize(copy_stager: CopyStager.new)
    @copy_stager = copy_stager
  end

  def apply(plan)
    copy_stager.stage(plan) do |staged_copies|
      plan.each { |operation| apply_operation(operation, staged_copies) }
    end
  end

  private

  attr_reader :copy_stager

  def apply_operation(operation, staged_copies)
    case operation.type
    when :create_directory
      FileUtils.mkdir_p(operation.path)
    when :create_symlink
      File.symlink(operation.source, operation.target)
    when :create_copy
      File.rename(staged_copies.path_for(operation), operation.target)
    when :move
      FileUtils.mv(operation.source, operation.target)
    when :remove
      FileUtils.rm_rf(operation.path)
    when :unchanged, :unchanged_copy
      nil
    end
  end
end
