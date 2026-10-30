#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative 'tooling'

HELP = <<~TEXT
  Usage: tools/install [--link] [name...]

  Build, then install every artifact declared in INSTALL_TARGETS
  (tools/settings.rb), or only the named ones, and verify each copy.

  Options:
    --link      Install a symbolic link to the source instead of a copy
                (interpreted Ruby artifacts only).
    -h, --help  Show this help; nothing is run.
TEXT

Tooling.entry(HELP) do
  link = ARGV.first == '--link'
  ARGV.shift if link
  Tooling.install(link: link, names: ARGV)
end
