# frozen_string_literal: true

require "fileutils"
require "open3"

module RemoteSkills
  class Cache
    def initialize(root)
      @root = root
    end

    def checkout(repo, sha)
      path = path_for(repo)
      FileUtils.mkdir_p(root)

      if Dir.exist?(File.join(path, ".git"))
        git(path, "fetch", "--quiet", "origin")
      else
        run("git", "clone", "--quiet", repo, path)
      end

      git(path, "checkout", "--quiet", sha)
      path
    end

    private

    attr_reader :root

    def path_for(repo)
      slug = repo.sub(%r{\A[^:]+://}, "").gsub(/[^A-Za-z0-9._-]+/, "-").gsub(/[.]+/, "-")
      File.join(root, slug)
    end

    def git(path, *args)
      run("git", "-C", path, *args)
    end

    def run(*args)
      output, status = Open3.capture2e(*args)
      raise "command failed: #{args.join(" ")}\n#{output.strip}" unless status.success?

      output
    end
  end
end
