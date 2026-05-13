# frozen_string_literal: true

module Assertions
  def assert_symlink(target, to: nil)
    assert File.symlink?(target), "Expected #{target} to be a symlink"
    assert_equal to, File.readlink(target) if to
  end

  def refute_symlink(target)
    refute File.symlink?(target), "Expected #{target} not to be a symlink"
  end

  def assert_reported_action(reporter, type, name: nil)
    action = reporter.actions.find do |candidate|
      candidate[:type] == type && (name.nil? || candidate[:meta][:name] == name)
    end

    assert action, "Expected reporter to include #{type.inspect} action"
  end
end
