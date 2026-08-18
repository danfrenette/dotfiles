# frozen_string_literal: true

module Phases
  class Skills
    class Plan
      attr_reader :package_manager

      def initialize(package_manager:)
        @package_manager = package_manager
        freeze
      end

      def command
        [package_manager, "dlx", "skills@#{VERSION}", "add", CATALOG, "--global", "--agent", "opencode"]
      end

      def items
        [{
          type: :skills,
          meta: {command: command, effect: "opens the skills CLI to select skills for global OpenCode"}
        }]
      end
    end
  end
end
