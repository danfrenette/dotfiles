# frozen_string_literal: true

require "test_helper"
require "remote_skills/sources"

class RemoteSkillsTest < DotfilesTestCase
  def setup
    super
    @manifest_path = tmp_path("skills.yml")
    @lock_path = tmp_path("skills.lock")
    @cache_root = tmp_path("cache")
  end

  def test_returns_empty_sources_when_manifest_has_no_remote_skills
    write_manifest([])

    sources = build_sources.sources

    assert_empty sources
  end

  def test_updates_lock_and_returns_checked_out_skill_sources
    write_manifest([
      {
        "name" => "reviewer",
        "repo" => "https://example.com/skills.git",
        "path" => "skills/reviewer",
        "ref" => "main"
      }
    ])

    sources = build_sources.sources(update: true)
    lock = YAML.safe_load_file(@lock_path)

    assert_equal File.join(@cache_root, "checkout", "skills", "reviewer"), sources["reviewer"]
    assert_equal "abc123", lock.fetch("remote_skills").first.fetch("sha")
  end

  def test_uses_locked_sha_without_resolving_ref
    write_manifest([
      {
        "name" => "reviewer",
        "repo" => "https://example.com/skills.git",
        "path" => "skills/reviewer",
        "ref" => "main"
      }
    ])
    write_lock([
      {
        "name" => "reviewer",
        "repo" => "https://example.com/skills.git",
        "path" => "skills/reviewer",
        "ref" => "main",
        "sha" => "locked456"
      }
    ])

    cache = FakeCache.new(@cache_root)

    sources = build_sources(cache: cache, resolver: ExplodingResolver.new).sources

    assert_equal File.join(@cache_root, "checkout", "skills", "reviewer"), sources["reviewer"]
    assert_equal [["https://example.com/skills.git", "locked456"]], cache.checkouts
  end

  private

  def build_sources(cache: FakeCache.new(@cache_root), resolver: FakeResolver.new)
    RemoteSkills::Sources.new(
      config: MockConfig.new(@manifest_path, @lock_path, @cache_root),
      cache: cache,
      resolver: resolver
    )
  end

  def write_manifest(remote_skills)
    File.write(@manifest_path, YAML.dump("remote_skills" => remote_skills))
  end

  def write_lock(remote_skills)
    File.write(@lock_path, YAML.dump("remote_skills" => remote_skills))
  end

  class MockConfig
    attr_reader :skills_manifest_path, :skills_lock_path, :skills_cache_dir

    def initialize(skills_manifest_path, skills_lock_path, skills_cache_dir)
      @skills_manifest_path = skills_manifest_path
      @skills_lock_path = skills_lock_path
      @skills_cache_dir = skills_cache_dir
    end
  end

  class FakeResolver
    def sha_for(_repo, _ref)
      "abc123"
    end
  end

  class ExplodingResolver
    def sha_for(_repo, _ref)
      raise "resolver should not be called"
    end
  end

  class FakeCache
    attr_reader :checkouts

    def initialize(root)
      @root = root
      @checkouts = []
    end

    def checkout(repo, sha)
      checkouts << [repo, sha]
      File.join(@root, "checkout")
    end
  end
end
