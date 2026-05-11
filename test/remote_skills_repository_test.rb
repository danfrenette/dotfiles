# frozen_string_literal: true

require "test_helper"
require "English"
require "yaml"
require "remote_skills/repository"
require "remote_skills/resolver"

class RemoteSkillsRepositoryTest < DotfilesTestCase
  def test_checks_out_each_resolved_skill_path
    repo = create_git_repo(
      "skills/reviewer/SKILL.md" => "---\nname: reviewer\n---\n",
      "skills/tdd/SKILL.md" => "---\nname: tdd\n---\n"
    )
    sha = git_commit_sha(repo)
    entries = [
      resolved_skill("reviewer", repo, sha, "skills/reviewer"),
      resolved_skill("tdd", repo, sha, "skills/tdd")
    ]

    sources = RemoteSkills::Repository.new(tmp_path("cache")).checkout_all(entries)

    assert_equal "reviewer", skill_name_at(sources.fetch("reviewer"))
    assert_equal "tdd", skill_name_at(sources.fetch("tdd"))
  end

  private

  def resolved_skill(name, repo, sha, path)
    RemoteSkills::Resolver::ResolvedEntry.new(
      name: name,
      repo: repo,
      sha: sha,
      paths: [path]
    )
  end

  def create_git_repo(files)
    repo = tmp_path("source-repo")
    FileUtils.mkdir_p(repo)
    run_git(repo, "init", "--quiet")

    files.each do |path, content|
      create_file(File.join(repo, path), content)
    end

    run_git(repo, "add", ".")
    run_git(repo, "-c", "user.name=Test", "-c", "user.email=test@example.com", "commit", "--quiet", "-m", "Initial commit")
    repo
  end

  def git_commit_sha(repo)
    run_git(repo, "rev-parse", "HEAD").strip
  end

  def skill_name_at(path)
    YAML.safe_load_file(File.join(path, "SKILL.md")).fetch("name")
  end

  def run_git(repo, *args)
    output = IO.popen(["git", "-C", repo, *args], &:read)
    raise "git failed: git -C #{repo} #{args.join(" ")}" unless $CHILD_STATUS.success?

    output
  end
end
