#!/usr/bin/env ruby
# frozen_string_literal: true

require 'optparse'
require 'date'
require 'json'
require 'time'
require 'open3'

# Bumps the version number in Cargo.toml & Cargo.lock, updates CHANGELOG.md,
# creates a git commit, and tags the release.
#
# 3-Tier Milestone Guard:
#   Tier 1: Fast gate (tools/gate or tools/check) runs on EVERY bump.
#   Tier 2: Milestone benchmark (tools/benchmark --rust-only) runs on every 5th bump.
#   Tier 3: Deep integration suite (tools/test_deep) runs on every 20th bump.
#
# Usage: ./tools/bump [major|minor|patch] [options]

options = { deep: false, skip_deep: false, push: true }
parser = OptionParser.new do |opts|
  opts.banner = 'Usage: ./tools/bump [major|minor|patch] [options]'
  opts.on('--deep', 'Force running all test tiers (Tier 2 benchmark + Tier 3 deep tests)') { options[:deep] = true }
  opts.on('--skip-deep', 'Skip Tier 2 and Tier 3 tests even on milestone bumps') { options[:skip_deep] = true }
  opts.on('--no-push', 'Do not push commit and tag to remote') { options[:push] = false }
  opts.on('-h', '--help', 'Show this help') do
    puts opts
    exit 0
  end
end

args = parser.parse(ARGV)
level = args[0] || 'patch'

unless %w[major minor patch].include?(level)
  puts parser.help
  exit 1
end

root_dir = File.expand_path('..', __dir__)
Dir.chdir(root_dir)

cargo_toml = File.join(root_dir, 'Cargo.toml')
cargo_lock = File.join(root_dir, 'Cargo.lock')
changelog_file = File.join(root_dir, 'CHANGELOG.md')
version_file = File.join(root_dir, 'VERSION')

unless File.exist?(cargo_toml)
  warn "Error: Cargo.toml not found at #{cargo_toml}"
  exit 1
end

# 1. Bump Count & State Management
state_file = File.join(root_dir, '.bump_state.json')
state = begin
  File.exist?(state_file) ? JSON.parse(File.read(state_file)) : {}
rescue StandardError
  {}
end

current_count = (state['count'] || 0) + 1
is_tier2 = (current_count % 5).zero?
is_tier3 = (current_count % 20).zero?
run_tier2 = (is_tier2 || options[:deep]) && !options[:skip_deep]
run_tier3 = (is_tier3 || options[:deep]) && !options[:skip_deep]

# 2. Phase 1: Tier 1 Fast Quality Gate (Every Bump)
puts "\n==> [Phase 1/3] Running Tier 1 Quality Gate..."
gate_script = [File.join(root_dir, 'tools', 'gate'), File.join(root_dir, 'tools', 'check')].find { |s| File.exist?(s) }
if gate_script
  unless system(gate_script)
    warn "\e[31m❌ Tier 1 quality gate failed. Aborting bump.\e[0m"
    exit 1
  end
  puts "\e[32m✔ Tier 1 tests passed.\e[0m"
else
  puts '  [SKIP] No tools/gate or tools/check script found.'
end

# 3. Phase 2: Tier 2 Milestone Benchmark (Every 5th Bump)
benchmark_script = File.join(root_dir, 'tools', 'benchmark')
if run_tier2 && File.exist?(benchmark_script)
  puts "\n\e[1;33m" + ('=' * 70)
  puts "🔔 Tier 2 Milestone: Bump ##{current_count} (Every 5th Bump)!"
  puts '   Executing Tier 2 BENCHMARK SUITE...'
  puts ('=' * 70) + "\e[0m\n"

  unless system(benchmark_script, '--rust-only')
    warn "\e[31m❌ Tier 2 benchmark suite failed. Aborting bump.\e[0m"
    exit 1
  end
  puts "\e[32m✔ Tier 2 benchmark suite passed!\e[0m"
elsif File.exist?(benchmark_script)
  rem = 5 - (current_count % 5)
  puts "--> Skipping Tier 2 benchmark tests. (Bump ##{current_count} — #{rem} bump#{'s' if rem > 1} until next Tier 2 run)."
end

# 4. Phase 3: Tier 3 Deep Toolchain Integration (Every 20th Bump)
deep_test_script = File.join(root_dir, 'tools', 'test_deep')
if run_tier3 && File.exist?(deep_test_script)
  puts "\n\e[1;33m" + ('=' * 70)
  puts "🔬 Tier 3 Milestone: Bump ##{current_count} (Every 20th Bump)!"
  puts '   Executing Tier 3 DEEP INTEGRATION SUITE...'
  puts ('=' * 70) + "\e[0m\n"

  unless system(deep_test_script)
    warn "\e[31m❌ Tier 3 deep integration suite failed. Aborting bump.\e[0m"
    exit 1
  end
  puts "\e[32m✔ Tier 3 deep integration suite passed!\e[0m"
elsif File.exist?(deep_test_script)
  rem = 20 - (current_count % 20)
  puts "--> Skipping Tier 3 deep tests. (Bump ##{current_count} — #{rem} bump#{'s' if rem > 1} until next Tier 3 run)."
end

# 5. Version Calculation & File Updates
content = File.read(cargo_toml)
current_version = content[/^version\s*=\s*["']([^"']+)["']/, 1]
unless current_version
  warn "Error: Unable to extract version from #{cargo_toml}"
  exit 1
end

major, minor, patch = current_version.split('.').map(&:to_i)
case level
when 'major'
  major += 1
  minor = 0
  patch = 0
when 'minor'
  minor += 1
  patch = 0
when 'patch'
  patch += 1
end

new_version = "#{major}.#{minor}.#{patch}"
puts "\nBumping version from #{current_version} to \e[1;32m#{new_version}\e[0m..."

# Write new version in Cargo.toml
new_content = content.sub(/^version\s*=\s*["'][^"']+["']/, "version = \"#{new_version}\"")
File.write(cargo_toml, new_content)

# Update VERSION file if present
File.write(version_file, "#{new_version}\n") if File.exist?(version_file)

# Synchronize Cargo.lock
system('cargo check >/dev/null 2>&1') if File.exist?(cargo_lock)

# Update CHANGELOG.md if present
if File.exist?(changelog_file)
  changelog = File.read(changelog_file)
  date = Date.today.to_s
  new_changelog = changelog.sub('## [Unreleased]', "## [Unreleased]\n\n## [#{new_version}] - #{date}")
  File.write(changelog_file, new_changelog)
  puts 'Updated CHANGELOG.md'
end

# Save bump state
state['count'] = current_count
state['last_bumped_at'] = Time.now.iso8601
state['version'] = new_version
File.write(state_file, JSON.pretty_generate(state))

# 6. Git Commit, Tag, and Push
if system('git rev-parse --is-inside-work-tree >/dev/null 2>&1')
  files_to_add = ['Cargo.toml', '.bump_state.json']
  files_to_add << 'Cargo.lock' if File.exist?(cargo_lock)
  files_to_add << 'CHANGELOG.md' if File.exist?(changelog_file)
  files_to_add << 'VERSION' if File.exist?(version_file)

  system("git add #{files_to_add.join(' ')}")
  system("git commit -m \"chore: bump version to #{new_version}\"")
  system("git tag -a v#{new_version} -m \"Release v#{new_version}\"")
  puts "\e[32m✔ Committed and tagged v#{new_version}\e[0m"

  if options[:push]
    puts 'Pushing commits and tags to remote...'
    system('git push --follow-tags')
  else
    puts 'Push skipped (--no-push).'
  end
end

# 7. Install if install tool or Makefile target exists
install_script = File.join(root_dir, 'tools', 'install')
if File.exist?(install_script) && File.executable?(install_script)
  system(install_script)
elsif File.exist?(File.join(root_dir, 'Makefile')) && File.read(File.join(root_dir, 'Makefile')).include?('install:')
  system('make install')
end

puts "\e[32m✔ Successfully bumped to version #{new_version}!\e[0m"
exit 0
