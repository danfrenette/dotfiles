# frozen_string_literal: true

class TestConfig
  attr_reader :mappings,
    :nvim_configuration_targets,
    :nvim_plugin_manager_path,
    :brewfile_path,
    :opencode2_global_dir,
    :user_bin_dir,
    :opencode_fork_checkout,
    :pnpm_candidates

  def initialize(
    mappings: [],
    nvim_configuration_targets: [],
    nvim_plugin_manager_path: "/nonexistent/plug.vim",
    brewfile_path: "/nonexistent/Brewfile",
    opencode2_global_dir: "/nonexistent/opencode2-global",
    user_bin_dir: "/nonexistent/bin",
    opencode_fork_checkout: "/nonexistent/code/opencode",
    pnpm_candidates: ["/fake/pnpm"]
  )
    @mappings = mappings
    @nvim_configuration_targets = nvim_configuration_targets
    @nvim_plugin_manager_path = nvim_plugin_manager_path
    @brewfile_path = brewfile_path
    @opencode2_global_dir = opencode2_global_dir
    @user_bin_dir = user_bin_dir
    @opencode_fork_checkout = opencode_fork_checkout
    @pnpm_candidates = pnpm_candidates
  end
end
