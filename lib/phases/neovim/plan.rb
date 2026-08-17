# frozen_string_literal: true

module Phases
  class Neovim
    class Plan
      attr_reader :executable, :configuration_targets

      def initialize(executable:, configuration_targets:)
        @executable = executable
        @configuration_targets = configuration_targets.dup.freeze
        freeze
      end

      def command
        [executable, "--headless", "+PlugInstall", "+qa"]
      end

      def items
        [{
          type: :neovim,
          meta: {executable: executable, configuration_targets: configuration_targets, command: command}
        }]
      end
    end
  end
end
