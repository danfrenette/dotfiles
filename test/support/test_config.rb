# frozen_string_literal: true

class TestConfig
  attr_reader :skills_source_root,
    :opencode_skills_target,
    :local_skills,
    :skills_manifest_path,
    :mappings,
    :nvim_init_target,
    :brewfile_path

  def initialize(
    skills_source_root:,
    opencode_skills_target:,
    skills_manifest_path:,
    local_skills: [],
    mappings: {},
    nvim_init_target: "/nonexistent/path/init.lua",
    brewfile_path: "/nonexistent/Brewfile"
  )
    @skills_source_root = skills_source_root
    @opencode_skills_target = opencode_skills_target
    @local_skills = local_skills
    @skills_manifest_path = skills_manifest_path
    @mappings = mappings
    @nvim_init_target = nvim_init_target
    @brewfile_path = brewfile_path
  end
end
