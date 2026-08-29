# frozen_string_literal: true

require "yaml"

module Phases
  class Skills
    class Catalog
      def self.load(path)
        YAML.safe_load_file(path).fetch("catalogs").map do |attributes|
          new(attributes.fetch("source"), Array(attributes.fetch("skills")))
        end
      end

      def initialize(source, skills)
        @source = source
        @skills = skills
      end

      def command(package_manager:)
        [
          package_manager, "dlx", "skills@#{VERSION}", "add", source,
          "--global", "--agent", "opencode", "cursor", "--skill", *skills, "--yes"
        ]
      end

      private

      attr_reader :source, :skills
    end
  end
end
