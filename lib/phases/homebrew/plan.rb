# frozen_string_literal: true

module Phases
  class Homebrew
    class Plan
      attr_reader :executable, :brewfile

      def initialize(executable:, brewfile:)
        @executable = executable
        @brewfile = brewfile
        freeze
      end

      def command
        [executable, "bundle", "--file=#{brewfile}"]
      end

      def items
        [
          {type: :available, meta: {path: executable}},
          {
            type: :bundle,
            meta: {
              command: command,
              brewfile: brewfile,
              effect: "install or update declared packages"
            }
          }
        ]
      end
    end
  end
end
