# frozen_string_literal: true

require "test_helper"
require "remote_skills/sources"
require "remote_skills/resolver"

class RemoteSkillsSourcesTest < DotfilesTestCase
  def test_returns_empty_sources_without_checkout_when_nothing_resolves
    resolver = StubResolver.new([])
    repository = RecordingRepository.new

    sources = build_sources(resolver, repository).sources(update: true)

    assert_empty sources
    assert_equal [true], resolver.updates
    assert_empty repository.checked_out_entries
  end

  def test_checks_out_resolved_entries
    entry = RemoteSkills::Resolver::ResolvedEntry.new(
      name: "reviewer",
      repo: "https://example.com/skills.git",
      sha: "abc123",
      paths: ["skills/reviewer"]
    )
    resolver = StubResolver.new([entry])
    repository = RecordingRepository.new("reviewer" => "/cache/reviewer")

    sources = build_sources(resolver, repository).sources(update: false)

    assert_equal({"reviewer" => "/cache/reviewer"}, sources)
    assert_equal [false], resolver.updates
    assert_equal [entry], repository.checked_out_entries
  end

  private

  def build_sources(resolver, repository)
    RemoteSkills::Sources.new(
      config: MockConfig.new(tmp_path("skills.yml"), tmp_path("skills.lock"), tmp_path("cache")),
      resolver: resolver,
      repository: repository
    )
  end

  class MockConfig
    attr_reader :skills_manifest_path, :skills_lock_path, :skills_cache_dir

    def initialize(skills_manifest_path, skills_lock_path, skills_cache_dir)
      @skills_manifest_path = skills_manifest_path
      @skills_lock_path = skills_lock_path
      @skills_cache_dir = skills_cache_dir
    end
  end

  class StubResolver
    attr_reader :updates

    def initialize(entries)
      @entries = entries
      @updates = []
    end

    def resolve(update: false)
      @updates << update
      @entries
    end
  end

  class RecordingRepository
    attr_reader :checked_out_entries

    def initialize(sources = {})
      @sources = sources
      @checked_out_entries = []
    end

    def checkout_all(entries)
      @checked_out_entries = entries
      @sources
    end
  end
end
