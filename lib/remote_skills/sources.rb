# frozen_string_literal: true

require_relative "cache"
require_relative "lock"
require_relative "manifest"
require_relative "ref_resolver"

module RemoteSkills
  class Sources
    def initialize(config:, manifest: nil, lock: nil, cache: nil, resolver: nil)
      @manifest = manifest || Manifest.new(config.skills_manifest_path)
      @lock = lock || Lock.new(config.skills_lock_path)
      @cache = cache || Cache.new(config.skills_cache_dir)
      @resolver = resolver || RefResolver.new
    end

    def sources(update: false)
      entries = manifest.entries
      return {} if entries.empty?

      lock.write(entries, resolver) if update

      entries.to_h do |entry|
        checkout = cache.checkout(entry.repo, lock.sha_for(entry), sparse_path: entry.path)
        [entry.name, File.join(checkout, entry.path)]
      end
    end

    private

    attr_reader :manifest, :lock, :cache, :resolver
  end
end
