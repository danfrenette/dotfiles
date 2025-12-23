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
