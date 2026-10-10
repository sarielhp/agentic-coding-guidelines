#!/usr/bin/env ruby
# frozen_string_literal: true

require 'optparse'
require 'open3'
require 'fileutils'

# Semantic version bumper for Ruby projects.
# Finds the VERSION constant (lib/**/version.rb, version.rb, or a bin/ script),
# bumps it, runs the quality gate unless HEAD was already verified by tools/commit,
# commits, tags, pushes, and installs via tools/install when present.

options = { type: :patch, push: true, install: true }

OptionParser.new do |opts|
  opts.banner = 'Usage: ./tools/bump [options]'
  opts.on('--major', 'Increment major version') { options[:type] = :major }
  opts.on('--minor', 'Increment minor version') { options[:type] = :minor }
  opts.on('--patch', 'Increment patch version (default)') { options[:type] = :patch }
  opts.on('--no-push', 'Do not push commit and tags to remote') { options[:push] = false }
  opts.on('--no-install', 'Do not run tools/install after the release') { options[:install] = false }
  opts.on('-h', '--help', 'Show this help') do
    puts opts
    exit 0
  end
end.parse!

root_dir = File.expand_path('..', __dir__)
Dir.chdir(root_dir)

VERSION_RE = /(VERSION\s*=\s*['"])(\d+(?:\.\d+)*)(['"])/

# Ensure clean git state
unless `git status --porcelain`.strip.empty?
  warn "\e[31m❌ Working directory is dirty. Commit or stash changes first.\e[0m"
  exit 1
end

# Find the version file: conventional version.rb first, then a bin/ script carrying VERSION
candidates = Dir.glob('lib/**/version.rb') + Dir.glob('version.rb') + Dir.glob('bin/*').select { |f| File.file?(f) }
version_file = candidates.find { |f| File.read(f).match?(VERSION_RE) }
unless version_file
  warn "\e[31m❌ No VERSION constant found in lib/**/version.rb, version.rb or bin/*.\e[0m"
  exit 1
end

content = File.read(version_file)
match = content.match(VERSION_RE)
current_version = match[2]

parts = current_version.split('.').map(&:to_i)
parts << 0 while parts.size < 3
case options[:type]
when :major then parts = [parts[0] + 1, 0, 0]
when :minor then parts = [parts[0], parts[1] + 1, 0]
when :patch then parts[2] += 1
end
new_version = parts.join('.')
puts "\e[1;36m==> Bumping version: #{current_version} -> #{new_version} (#{version_file})\e[0m"
File.write(version_file, content.sub(VERSION_RE, "\\1#{new_version}\\3"))

# Quality gate, unless this exact HEAD already passed it via tools/commit and the
# only working-tree change is the version bump we just made.
verified_file = File.join(root_dir, '.verified_head')
head_verified = File.exist?(verified_file) && File.read(verified_file).strip == `git rev-parse HEAD`.strip
changed = `git status --porcelain`.lines.map { |l| l.strip.split(/\s+/).last }
gate_script = [File.join(root_dir, 'tools', 'gate'), File.join(root_dir, 'tools', 'check')].find { |s| File.exist?(s) }
if head_verified && (changed - [version_file]).empty?
  puts "\e[1;36m==> HEAD already gate-verified (.verified_head); skipping gate.\e[0m"
elsif gate_script
  puts "\e[1;36m==> Running Quality Gate...\e[0m"
  unless system(gate_script)
    warn "\e[31m❌ Quality gate failed. Rolling back version bump.\e[0m"
    File.write(version_file, content)
    exit 1
  end
end

# Commit, tag, push
system('git', 'add', version_file)
system('git', 'commit', '-m', "release: v#{new_version}")
system('git', 'tag', '-a', "v#{new_version}", '-m', "Release v#{new_version}")

if options[:push] && !`git remote`.strip.empty?
  puts "\e[1;36m==> Pushing release and tags...\e[0m"
  curr_branch = `git rev-parse --abbrev-ref HEAD`.strip
  system('git', 'push', '--follow-tags', 'origin', curr_branch)
end
FileUtils.rm_f(verified_file)
puts "\e[32m✔ Successfully released v#{new_version}!\e[0m"

# Install (tools/install runs tools/build itself)
install_script = File.join(root_dir, 'tools', 'install')
if options[:install] && File.executable?(install_script)
  puts "\e[1;36m==> Installing via tools/install...\e[0m"
  exit 1 unless system(install_script)
end
