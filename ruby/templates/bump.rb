#!/usr/bin/env ruby
# frozen_string_literal: true

require 'optparse'
require 'open3'

# Semantic version bumper for Ruby projects.
# Increments version, runs quality gate, commits, tags, and pushes.

options = { type: :patch, push: true }

OptionParser.new do |opts|
  opts.banner = 'Usage: ./tools/bump [options]'
  opts.on('--major', 'Increment major version') { options[:type] = :major }
  opts.on('--minor', 'Increment minor version') { options[:type] = :minor }
  opts.on('--patch', 'Increment patch version (default)') { options[:type] = :patch }
  opts.on('--no-push', 'Do not push commit and tags to remote') { options[:push] = false }
  opts.on('-h', '--help', 'Show this help') do
    puts opts
    exit 0
  end
end.parse!

root_dir = File.expand_path('..', __dir__)
Dir.chdir(root_dir)

# Ensure clean git state
status = `git status --porcelain`.strip
unless status.empty?
  warn "\e[31m❌ Working directory is dirty. Commit or stash changes first.\e[0m"
  exit 1
end

# Find version file
version_files = Dir.glob('lib/**/version.rb') + Dir.glob('version.rb')
version_file = version_files.first

unless version_file && File.file?(version_file)
  warn "\e[31m❌ Could not find version.rb in lib/ or project root.\e[0m"
  exit 1
end

content = File.read(version_file)
unless content =~ /(VERSION\s*=\s*['"])([\d\.]+)(['"])/
  warn "\e[31m❌ Could not parse VERSION constant in #{version_file}\e[0m"
  exit 1
end

prefix = Regexp.last_match(1)
current_version = Regexp.last_match(2)
suffix = Regexp.last_match(3)

parts = current_version.split('.').map(&:to_i)
while parts.size < 3
  parts << 0
end

case options[:type]
when :major
  parts[0] += 1
  parts[1] = 0
  parts[2] = 0
when :minor
  parts[1] += 1
  parts[2] = 0
when :patch
  parts[2] += 1
end

new_version = parts.join('.')
puts "\e[1;36m==> Bumping version: #{current_version} -> #{new_version}\e[0m"

# Update version file
new_content = content.sub(/(VERSION\s*=\s*['"])([\d\.]+)(['"])/, "#{prefix}#{new_version}#{suffix}")
File.write(version_file, new_content)

# Run Quality Gate
gate_script = [File.join(root_dir, 'tools', 'gate'), File.join(root_dir, 'tools', 'check')].find { |s| File.exist?(s) }
if gate_script
  puts "\e[1;36m==> Running Quality Gate...\e[0m"
  unless system(gate_script)
    warn "\e[31m❌ Quality gate failed. Rolling back version bump.\e[0m"
    File.write(version_file, content)
    exit 1
  end
end

# Git commit and tag
system('git', 'add', version_file)
system('git', 'commit', '-m', "release: v#{new_version}")
system('git', 'tag', '-a', "v#{new_version}", '-m', "Release v#{new_version}")

if options[:push] && !`git remote`.strip.empty?
  puts "\e[1;36m==> Pushing release and tags...\e[0m"
  curr_branch = `git rev-parse --abbrev-ref HEAD`.strip
  system('git', 'push', '--follow-tags', 'origin', curr_branch)
end

puts "\e[32m✔ Successfully released v#{new_version}!\e[0m\n\n"
