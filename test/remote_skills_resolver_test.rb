# frozen_string_literal: true

require "test_helper"
require "yaml"
require "remote_skills/resolver"

class RemoteSkillsResolverTest < DotfilesTestCase
  def setup
    super
    @manifest_path = tmp_path("skills.yml")
    @lock_path = tmp_path("skills.lock")
    @ref_resolver = RecordingRefResolver.new(
      "main" => "1111111111111111111111111111111111111111",
      "v1.0.0" => "2222222222222222222222222222222222222222"
    )
  end

  def test_returns_no_entries_when_manifest_has_no_remote_skills
    write_manifest([])

    assert_empty resolver.resolve
  end

  def test_update_resolves_manifest_refs_and_writes_lockfile
    write_manifest([
      skill("reviewer", ref: "main"),
      skill("tdd", path: "skills/tdd", ref: "v1.0.0")
    ])

    entries = resolver.resolve(update: true)

    assert_equal ["reviewer", "tdd"], entries.map(&:name)
    assert_equal [
      "1111111111111111111111111111111111111111",
      "2222222222222222222222222222222222222222"
    ], entries.map(&:sha)
    assert_equal [
      ["https://example.com/skills.git", "main"],
      ["https://example.com/skills.git", "v1.0.0"]
    ], @ref_resolver.calls
    assert_equal [
      skill("reviewer", ref: "main").merge("sha" => "1111111111111111111111111111111111111111"),
      skill("tdd", path: "skills/tdd", ref: "v1.0.0").merge("sha" => "2222222222222222222222222222222222222222")
    ], lockfile_entries
  end

  def test_uses_locked_sha_without_resolving_ref
    write_manifest([skill("reviewer", ref: "main")])
    write_lock([skill("reviewer", ref: "main").merge("sha" => "locked4567890123456789012345678901234567890")])

    entries = resolver.resolve

    assert_equal "locked4567890123456789012345678901234567890", entries.fetch(0).sha
    assert_empty @ref_resolver.calls
  end

  def test_resolves_ref_when_lockfile_has_no_entry
    write_manifest([skill("reviewer", ref: "main")])
    write_lock([])

    entries = resolver.resolve

    assert_equal "1111111111111111111111111111111111111111", entries.fetch(0).sha
    assert_equal [["https://example.com/skills.git", "main"]], @ref_resolver.calls
  end

  private

  def resolver
    RemoteSkills::Resolver.new(
      manifest_path: @manifest_path,
      lock_path: @lock_path,
      ref_resolver: @ref_resolver
    )
  end

  def skill(name, ref:, path: "skills/#{name}")
    {
      "name" => name,
      "repo" => "https://example.com/skills.git",
      "path" => path,
      "ref" => ref
    }
  end

  def write_manifest(remote_skills)
    File.write(@manifest_path, YAML.dump("remote_skills" => remote_skills))
  end

  def write_lock(remote_skills)
    File.write(@lock_path, YAML.dump("remote_skills" => remote_skills))
  end

  def lockfile_entries
    YAML.safe_load_file(@lock_path).fetch("remote_skills")
  end

  class RecordingRefResolver
    attr_reader :calls

    def initialize(shas_by_ref)
      @shas_by_ref = shas_by_ref
      @calls = []
    end

    def sha_for(repo, ref)
      @calls << [repo, ref]
      @shas_by_ref.fetch(ref)
    end
  end
end
