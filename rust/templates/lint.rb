#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative 'tooling'

HELP = <<~TEXT
  Usage: tools/lint

  Static feedback only: cargo fmt --check, cargo clippy -D warnings and
  rust-audit --strict. No tests.

  Options:
    -h, --help  Show this help; nothing is run.
TEXT

Tooling.entry(HELP) do
  abort 'Usage: tools/lint' unless ARGV.empty?
  Language.lint
end
