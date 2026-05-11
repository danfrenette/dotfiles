# frozen_string_literal: true

require "fileutils"
require "open3"

module RemoteSkills
  class Cache
    def initialize(root)
      @root = root
    end

    def checkout(repo, sha, sparse_path: nil)
      path = path_for(repo)
      FileUtils.mkdir_p(root)

      if Dir.exist?(File.join(path, ".git"))
        git(path, "fetch", "--quiet", "origin")
        configure_sparse_checkout(path, sparse_path) if sparse_path
      else
        clone_sparse(repo, path, sparse_path)
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

    def clone_sparse(repo, path, sparse_path)
      run("git", "clone", "--filter=blob:none", "--sparse", "--quiet", repo, path)
      configure_sparse_checkout(path, sparse_path) if sparse_path
    end

    def configure_sparse_checkout(path, sparse_path)
      git(path, "sparse-checkout", "set", "--no-cone", sparse_path)
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
