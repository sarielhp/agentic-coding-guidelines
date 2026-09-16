#!/usr/bin/env ruby
# frozen_string_literal: true

require 'fileutils'
require 'open3'

# Builds and installs the Rust binary directly into ~/bin via cargo install.
# Usage: ./tools/install [cargo install options...]

root_dir = File.expand_path('..', __dir__)
cargo_toml = File.join(root_dir, 'Cargo.toml')

unless File.exist?(cargo_toml)
  abort "Error: Cargo.toml not found in repository root (#{root_dir})."
end

unless system('command -v cargo >/dev/null 2>&1')
  abort 'Error: cargo binary not found in PATH.'
end

pkg_name = File.read(cargo_toml)[/^name\s*=\s*["']([^"']+)["']/, 1] || File.basename(root_dir)

puts "==> Installing #{pkg_name} directly into ~/bin via cargo install..."

Dir.chdir(root_dir) do
  cmd = ['cargo', 'install', '--path', '.', '--root', File.expand_path('~'), '--force'] + ARGV
  success = system(*cmd)
  unless success
    warn "\e[31m❌ Failed to install #{pkg_name} via cargo.\e[0m"
    exit 1
  end
end

puts "\n\e[32m==> Installation complete!\e[0m"
bin_path = `which #{pkg_name} 2>/dev/null`.strip
if !bin_path.empty?
  puts "#{pkg_name} is available in PATH at: #{bin_path}"
  version_out = `#{pkg_name} --version 2>/dev/null`.strip
  puts "Version: #{version_out}" unless version_out.empty?
else
  warn "\nNote: '#{pkg_name}' is not currently in your PATH."
  warn 'Ensure ~/bin is added to your PATH:'
  warn '  export PATH="$HOME/bin:$PATH"'
end

exit 0
