# frozen_string_literal: true

require "yaml"
require_relative "entry"
require_relative "git_ref_resolver"

module RemoteSkills
  # Resolves manifest entries to locked SHAs
  class Resolver
    ResolvedEntry = Data.define(:name, :repo, :sha, :paths)

    def initialize(manifest_path:, lock_path:, ref_resolver: nil)
      @manifest_path = manifest_path
      @lock_path = lock_path
      @ref_resolver = ref_resolver || GitRefResolver.new
    end

    def resolve(update: false)
      entries = load_manifest
      return [] if entries.empty?

      return update_lock(entries) if update

      resolve_from_lock(entries)
    end

    private

    attr_reader :manifest_path, :lock_path, :ref_resolver

    def load_manifest
      data = YAML.safe_load_file(manifest_path) || {}
      Array(data["remote_skills"]).map do |attrs|
        Entry.new(
          name: attrs.fetch("name"),
          repo: attrs.fetch("repo"),
          path: attrs.fetch("path"),
          ref: attrs.fetch("ref")
        )
      end
    end

    def update_lock(entries)
      resolved_entries = resolve_refs(entries)
      write_lock(entries, resolved_entries)
      resolved_entries
    end

    def resolve_from_lock(entries)
      locked = load_lock
      entries.map do |entry|
        sha = locked[entry.name] || resolve_single(entry)
        to_resolved(entry, sha)
      end
    end

    def resolve_refs(entries)
      entries.map do |entry|
        to_resolved(entry, resolve_single(entry))
      end
    end

    def to_resolved(entry, sha)
      ResolvedEntry.new(
        name: entry.name,
        repo: entry.repo,
        sha: sha,
        paths: [entry.path]
      )
    end

    def resolve_single(entry)
      ref_resolver.sha_for(entry.repo, entry.ref)
    end

    def load_lock
      return {} unless File.exist?(lock_path)
      data = YAML.safe_load_file(lock_path) || {}
      Array(data["remote_skills"]).to_h { |r| [r["name"], r["sha"]] }
    end

    def write_lock(entries, resolved_entries)
      payload = {
        "remote_skills" => entries.zip(resolved_entries).map do |entry, resolved|
          {
            "name" => entry.name,
            "repo" => entry.repo,
            "path" => entry.path,
            "ref" => entry.ref,
            "sha" => resolved.sha
          }
        end
      }
      File.write(lock_path, YAML.dump(payload))
    end
  end
end
