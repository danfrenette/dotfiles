#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative "lib/installer"

skip_brew = ARGV.include?("--skip-brew") || ARGV.include?("-s")
dry_run = ARGV.include?("--dry-run") || ARGV.include?("-n")
update_skills = ARGV.include?("--update-skills") || ARGV.include?("-u")
skills_only = ARGV.include?("--skills-only")

Installer.new(skip_brew: skip_brew, dry_run: dry_run, update_skills: update_skills, skills_only: skills_only).install
