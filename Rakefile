# frozen_string_literal: true

require "rake/testtask"
require "standard/rake"

Rake::TestTask.new(:test) do |t|
  t.libs << "test"
  t.libs << "lib"
  t.test_files = FileList["test/**/*_test.rb"]
end

task default: %i[test standard]

# Homebrew tasks
namespace :brew do
  desc "Install Homebrew packages from Brewfile"
  task :install do
    sh "brew bundle --file=Brewfile"
  end

  desc "Check which Homebrew packages are missing"
  task :check do
    sh "brew bundle check --file=Brewfile || true"
  end

  desc "List all installed packages"
  task :list do
    sh "brew bundle list --file=Brewfile"
  end
end

desc "Install Homebrew packages"
task brew: "brew:install"

# OpenCode tasks
namespace :opencode_beta do
  desc "Install or update opencode-beta (bun global install of opencode-ai, renamed to opencode-beta)"
  task :install do
    bun_bin = File.join(Dir.home, ".bun", "bin")
    opencode_bin = File.join(bun_bin, "opencode")
    opencode_beta_bin = File.join(bun_bin, "opencode-beta")

    puts "Installing opencode-ai via bun..."
    abort "bun install failed" unless system("bun install -g opencode-ai@beta")

    if File.exist?(opencode_bin)
      File.rename(opencode_bin, opencode_beta_bin)
      puts "  Renamed opencode -> opencode-beta"
    end

    puts "  Done -> #{opencode_beta_bin}"
  end
end
