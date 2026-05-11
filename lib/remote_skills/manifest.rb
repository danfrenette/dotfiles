# frozen_string_literal: true

require "yaml"
require_relative "entry"

module RemoteSkills
  class Manifest
    def initialize(path)
      @path = path
    end

    def entries
      Array(data["remote_skills"]).map do |attributes|
        Entry.new(
          name: attributes.fetch("name"),
          repo: attributes.fetch("repo"),
          path: attributes.fetch("path"),
          ref: attributes.fetch("ref")
        )
      end
    end

    private

    attr_reader :path

    def data
      YAML.safe_load_file(path) || {}
    end
  end
end
