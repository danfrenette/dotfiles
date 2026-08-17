# frozen_string_literal: true

class TestConfig
  attr_reader :skills_source_root,
    :opencode_skills_target,
    :local_skills,
    :skills_manifest_path,
    :mappings,
    :nvim_init_target,
    :brewfile_path,
    :opencode2_global_dir,
    :user_bin_dir,
    :opencode_fork_checkout,
    :pnpm_candidates

  def initialize(
    skills_source_root:,
    opencode_skills_target:,
    skills_manifest_path:,
    local_skills: [],
    mappings: [],
    nvim_init_target: "/nonexistent/path/init.lua",
    brewfile_path: "/nonexistent/Brewfile",
    opencode2_global_dir: "/nonexistent/opencode2-global",
    user_bin_dir: "/nonexistent/bin",
    opencode_fork_checkout: "/nonexistent/code/opencode",
    pnpm_candidates: ["/fake/pnpm"]
  )
    @skills_source_root = skills_source_root
    @opencode_skills_target = opencode_skills_target
    @local_skills = local_skills
    @skills_manifest_path = skills_manifest_path
    @mappings = mappings
    @nvim_init_target = nvim_init_target
    @brewfile_path = brewfile_path
    @opencode2_global_dir = opencode2_global_dir
    @user_bin_dir = user_bin_dir
    @opencode_fork_checkout = opencode_fork_checkout
    @pnpm_candidates = pnpm_candidates
  end
end
