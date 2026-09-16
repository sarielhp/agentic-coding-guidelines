#!/usr/bin/env ruby
# frozen_string_literal: true

require 'optparse'
require 'open3'

# Automates quality gate check, staging, committing, and pushing for Rust projects.
# Usage: ./tools/commit [options] "commit message"

options = { push: true, gate: true }
parser = OptionParser.new do |opts|
  opts.banner = 'Usage: ./tools/commit [options] "commit message"'
  opts.on('-m MESSAGE', 'Commit message') { |msg| options[:message] = msg }
  opts.on('--skip-gate', '-f', 'Skip quality gate before committing') { options[:gate] = false }
  opts.on('--no-push', 'Commit locally without pushing to remote') { options[:push] = false }
  opts.on('-h', '--help', 'Show this help') do
    puts opts
    exit 0
  end
end

remaining = parser.parse(ARGV)
message = options[:message] || remaining.join(' ').strip

if message.empty?
  puts parser.help
  exit 1
end

root_dir = File.expand_path('..', __dir__)
Dir.chdir(root_dir)

status = `git status --porcelain`.strip
if status.empty?
  puts "\e[33mNothing to commit (working tree clean).\e[0m"
  exit 0
end

# 1. Quality Gate
if options[:gate]
  puts "\e[1;36m==> Running Quality Gate before committing...\e[0m"
  gate_script = [File.join(root_dir, 'tools', 'gate'), File.join(root_dir, 'tools', 'check')].find { |s| File.exist?(s) }
  if gate_script
    unless system(gate_script)
      warn "\e[31m❌ Quality gate failed. Commit aborted.\e[0m"
      exit 1
    end
  end
end

# 2. Stage Changes
puts "\e[1;36m==> Staging changes...\e[0m"
_, _, s = Open3.capture3('git add -A')
unless s.success?
  warn "\e[31m❌ Failed to stage changes.\e[0m"
  exit 1
end

# 3. Commit
puts "\e[1;36m==> Committing: \"#{message}\"...\e[0m"
out, err, s = Open3.capture3('git', 'commit', '-m', message)
unless s.success?
  warn out unless out.empty?
  warn err unless err.empty?
  exit 1
end

# 4. Record .verified_head
head = `git rev-parse HEAD`.strip
File.write(File.join(root_dir, '.verified_head'), head)

# 5. Push
if options[:push]
  puts "\e[1;36m==> Pushing to remote...\e[0m"
  _, err, s = Open3.capture3('git push')
  unless s.success?
    warn "\e[31m❌ Git push failed:\e[0m\n#{err}"
    exit 1
  end
  puts "\e[32m✔ Successfully committed and pushed to remote!\e[0m"
else
  puts "\e[32m✔ Committed locally (push skipped).\e[0m"
end

exit 0
