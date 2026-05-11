# frozen_string_literal: true

require "yaml"

module RemoteSkills
  class Lock
    def initialize(path)
      @path = path
    end

    def sha_for(entry)
      locked_entry = entries.find { |candidate| candidate["name"] == entry.name }
      return locked_entry.fetch("sha") if locked_entry

      raise "#{path} does not include #{entry.name}; run ./install.rb --update-skills"
    end

    def write(entries, resolver)
      payload = {
        "remote_skills" => entries.map do |entry|
          {
            "name" => entry.name,
            "repo" => entry.repo,
            "path" => entry.path,
            "ref" => entry.ref,
            "sha" => resolver.sha_for(entry.repo, entry.ref)
          }
        end
      }

      File.write(path, YAML.dump(payload))
    end

    private

    attr_reader :path

    def entries
      Array((YAML.safe_load_file(path) || {})["remote_skills"])
    end
  end
end
