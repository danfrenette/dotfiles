# frozen_string_literal: true

require "fileutils"
require_relative "neovim/plan"
require_relative "../prepared_phase"
require_relative "error"

module Phases
  class Neovim
    NAME = :neovim
    PLUGIN_MANAGER_URL = "https://raw.githubusercontent.com/junegunn/vim-plug/0.14.0/plug.vim"

    class Error < Phases::Error; end

    def initialize(load_configuration_targets:, plugin_manager_path:, availability:, command_runner:, reporter:)
      @load_configuration_targets = load_configuration_targets
      @plugin_manager_path = plugin_manager_path
      @availability = availability
      @command_runner = command_runner
      @reporter = reporter
    end

    def name
      NAME
    end

    def prepare
      plan = build_plan
      PreparedPhase.new(plan) { apply(plan) }
    end

    private

    attr_reader :load_configuration_targets, :plugin_manager_path, :availability, :command_runner, :reporter

    def build_plan
      reporter.report_phase("Installing Neovim plugins")

      executable = command_runner.find_executable("nvim")
      raise Error, "Neovim not found; install nvim before running this phase" unless executable
      unless File.file?(plugin_manager_path)
        curl = command_runner.find_executable("curl", candidates: ["/usr/bin/curl"])
        raise Error, "curl not found; install curl before running this phase" unless curl
      end

      missing_targets = configuration_targets - availability.targets
      unless missing_targets.empty?
        raise Error, "Neovim configuration is not available: #{missing_targets.join(", ")}"
      end

      Plan.new(
        executable: executable,
        curl: curl,
        plugin_manager_path: plugin_manager_path,
        plugin_manager_url: PLUGIN_MANAGER_URL,
        configuration_targets: configuration_targets
      ).tap do |plan|
        plan.items.each { |item| reporter.report_action(item.fetch(:type), item.fetch(:meta)) }
      end
    end

    def apply(plan)
      unless File.file?(plan.plugin_manager_path)
        FileUtils.mkdir_p(File.dirname(plan.plugin_manager_path))
        result = command_runner.run(*plan.plugin_manager_command)
        raise Error, "vim-plug installation could not start" if result.nil?
        raise Error, "vim-plug installation exited with a nonzero status" unless result
        raise Error, "vim-plug was not installed at #{plan.plugin_manager_path}" unless File.file?(plan.plugin_manager_path)
      end

      result = command_runner.run(*plan.command)
      raise Error, "Neovim plugin installation could not start" if result.nil?
      raise Error, "Neovim plugin installation exited with a nonzero status" unless result

      reporter.report_action(:neovim_complete, command: plan.command)
    rescue SystemCallError => error
      raise Error, "Neovim filesystem operation failed: #{error.message}"
    end

    def configuration_targets
      @configuration_targets ||= load_configuration_targets.call
    end
  end
end
