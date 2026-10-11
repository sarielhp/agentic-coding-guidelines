#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative 'tooling'

Tooling.entry do
  abort 'Usage: tools/test' unless ARGV.empty?
  Language.test
end
