#!/usr/bin/env ruby
# frozen_string_literal: true

# tools/build for Rust projects. Contract (see ~/prog/standards/README.md, "tools/build"):
#   - produces the artifact inside the repository (target/release); exits non-zero on failure
#   - never writes outside the repository tree (installing is tools/install's job)
#   - runs no tests or linters (that is tools/gate's job)

ENV['PATH'] = "#{File.expand_path('~/.cargo/bin')}:#{ENV.fetch('PATH', '')}"
root_dir = File.expand_path('..', __dir__)
Dir.chdir(root_dir)
abort "\e[31m✗ tools/build: Cargo.toml not found in #{root_dir}.\e[0m" unless File.exist?('Cargo.toml')

puts '==> cargo build --release'
abort "\e[31m✗ Build failed.\e[0m" unless system('cargo', 'build', '--release', *ARGV)
puts "\e[32m✔ Build OK (target/release)\e[0m"
