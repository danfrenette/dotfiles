#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative "lib/installer"

skip_brew = ARGV.include?("--skip-brew") || ARGV.include?("-s")

Installer.new(skip_brew: skip_brew).install
