# frozen_string_literal: true

module Phases
  module OpenCode2
    class ForkWorkspace
      class Plan
        attr_reader :git, :bun, :bun_version, :repository, :branch, :checkout, :checkout_exists

        def initialize(git:, bun:, bun_version:, repository:, branch:, checkout:, checkout_exists:)
          @git = git
          @bun = bun
          @bun_version = bun_version
          @repository = repository
          @branch = branch
          @checkout = checkout
          @checkout_exists = checkout_exists
          freeze
        end

        def source_command
          if checkout_exists
            [git, "-C", checkout, "pull", "--ff-only", repository, branch]
          else
            [git, "clone", "--branch", branch, "--single-branch", repository, checkout]
          end
        end

        def dependency_command
          [bun, "install", "--frozen-lockfile", "--cwd", checkout]
        end

        def launch_command
          [bun, "run", "--cwd", checkout, "dev:web:live"]
        end

        def items
          [
            {
              type: :source,
              meta: {repository: repository, branch: branch, checkout: checkout, command: source_command}
            },
            {type: :dependencies, meta: {runtime: bun, version: bun_version, command: dependency_command}}
          ]
        end
      end
    end
  end
end
