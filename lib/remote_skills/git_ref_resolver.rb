# frozen_string_literal: true

require "open3"

module RemoteSkills
  # Resolves Git refs to SHAs via ls-remote
  class GitRefResolver
    def sha_for(repo, ref)
      output = ls_remote(repo, ref)
      parse_sha(output, ref, repo)
    end

    private

    def ls_remote(repo, ref)
      output, status = Open3.capture2e("git", "ls-remote", repo, ref)
      raise ResolutionError, "git ls-remote failed: #{output.strip}" unless status.success?
      output
    end

    def parse_sha(output, ref, repo)
      line = find_matching_line(output, ref)
      sha = extract_sha(line)
      validate_sha(sha, ref, repo)
    end

    def find_matching_line(output, ref)
      output.lines.find { |l| l.split.last == ref } || output.lines.first
    end

    def extract_sha(line)
      line&.split&.first
    end

    def validate_sha(sha, ref, repo)
      raise ResolutionError, "no SHA found for #{ref} in #{repo}" if sha.nil? || sha.empty?
      sha
    end

    class ResolutionError < StandardError; end
  end
end
