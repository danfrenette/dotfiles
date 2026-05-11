# frozen_string_literal: true

require "fileutils"
require "open3"

module RemoteSkills
  # Manages Git repository caching - fresh clone for simplicity
  class Repository
    def initialize(root)
      @root = root
    end

    # Clone all repos and return {skill_name => source_path}
    def checkout_all(resolved_entries)
      resolved_entries.to_h do |entry|
        path = clone(entry.repo, entry.sha)
        source = File.join(path, entry.paths.first)
        [entry.name, source]
      end
    end

    private

    attr_reader :root

    def clone(repo, sha)
      path = path_for(repo, sha)
      FileUtils.rm_rf(path)
      FileUtils.mkdir_p(File.dirname(path))

      run("git", "clone", "--quiet", repo, path)
      run("git", "-C", path, "checkout", "--quiet", sha)
      path
    end

    def path_for(repo, sha)
      slug = slugify(repo)
      File.join(root, slug, sha[0..7])
    end

    def slugify(repo)
      repo.sub(%r{\A[^:]+://}, "").gsub(/[^A-Za-z0-9._-]+/, "-").gsub(/[.]+/, "-")
    end

    def run(*args)
      output, status = Open3.capture2e(*args)
      raise RepositoryError, "git failed: #{args.join(" ")}\n#{output.strip}" unless status.success?
      output
    end

    class RepositoryError < StandardError; end
  end
end
