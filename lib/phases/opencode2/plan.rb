# frozen_string_literal: true

module Phases
  module OpenCode2
    class Plan
      attr_reader :cli, :fork

      def initialize(cli:, fork:)
        @cli = cli
        @fork = fork
        freeze
      end

      def items
        cli.items + fork.items + [
          {
            type: :service,
            meta: {command: cli.service_command, effect: "start the installed service that owns shared session data"}
          },
          {
            type: :workflow,
            meta: {
              name: "dev:web:live",
              command: fork.launch_command,
              effect: "proxy to the installed opencode2 service and shared sessions"
            }
          }
        ]
      end
    end
  end
end
