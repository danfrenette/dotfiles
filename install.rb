#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative "lib/installer"

skip_brew = ARGV.include?("--skip-brew") || ARGV.include?("-s")
dry_run = ARGV.include?("--dry-run") || ARGV.include?("-n")

Installer.new(skip_brew: skip_brew, dry_run: dry_run).install
