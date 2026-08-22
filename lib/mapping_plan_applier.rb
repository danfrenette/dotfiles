# frozen_string_literal: true

require "fileutils"

class MappingPlanApplier
  def apply(plan)
    plan.each { |operation| apply_operation(operation) }
  end

  private

  def apply_operation(operation)
    case operation.type
    when :create_directory
      FileUtils.mkdir_p(operation.path)
    when :create_symlink
      File.symlink(operation.source, operation.target)
    when :move
      FileUtils.mv(operation.source, operation.target)
    when :remove
      FileUtils.rm_rf(operation.path)
    when :unchanged
      nil
    end
  end
end
