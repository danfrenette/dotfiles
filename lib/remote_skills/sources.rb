# frozen_string_literal: true

require_relative "resolver"
require_relative "repository"

module RemoteSkills
  # Facade that coordinates resolution and checkout
  # Thin wrapper - can be deleted if callers use Resolver+Repository directly
  class Sources
    def initialize(config:, resolver: nil, repository: nil)
      @resolver = resolver || Resolver.new(
        manifest_path: config.skills_manifest_path,
        lock_path: config.skills_lock_path
      )
      @repository = repository || Repository.new(config.skills_cache_dir)
    end

    def sources(update: false)
      resolved = resolver.resolve(update: update)
      return {} if resolved.empty?

      repository.checkout_all(resolved)
    end

    private

    attr_reader :resolver, :repository
  end
end
