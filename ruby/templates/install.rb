#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative 'tooling'

Tooling.entry do
  link = ARGV.first == '--link'
  ARGV.shift if link
  Tooling.install(link: link, names: ARGV)
end
