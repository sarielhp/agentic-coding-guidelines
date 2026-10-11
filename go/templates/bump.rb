#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative 'tooling'

Tooling.entry do
  abort 'Usage: tools/bump [--resume]' unless ARGV.empty? || ARGV == ['--resume']
  ARGV.empty? ? Tooling.bump : Tooling.resume
end
