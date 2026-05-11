# frozen_string_literal: true

require "open3"

module RemoteSkills
  class RefResolver
    def sha_for(repo, ref)
      output, status = Open3.capture2e("git", "ls-remote", repo, ref)
      raise "failed to resolve #{ref} from #{repo}: #{output.strip}" unless status.success?

      line = output.lines.find { |candidate| candidate.split.last == ref } || output.lines.first
      sha = line&.split&.first
      raise "failed to resolve #{ref} from #{repo}" if sha.nil? || sha.empty?

      sha
    end
  end
end
