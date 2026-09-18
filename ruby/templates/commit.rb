#!/usr/bin/env ruby
# frozen_string_literal: true

require 'optparse'
require 'open3'

# Automates quality gate check, staging, committing, and pushing for Ruby projects.
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
if s.success?
  puts out
else
  warn err
  exit 1
end

# 4. Push
if options[:push]
  puts "\e[1;36m==> Pushing to remote...\e[0m"
  curr_branch = `git rev-parse --abbrev-ref HEAD`.strip
  remote_configured = !`git remote`.strip.empty?
  if remote_configured
    system('git', 'push', '--set-upstream', 'origin', curr_branch)
  else
    puts "  \e[33mℹ No git remote configured, skipping push.\e[0m"
  end
end

puts "\e[32m✔ Commit workflow complete.\e[0m\n\n"
