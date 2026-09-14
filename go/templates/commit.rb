#!/usr/bin/env ruby
# frozen_string_literal: true

require 'open3'

msg = ARGV.join(' ').strip
if msg.empty?
  warn "Usage: #{$PROGRAM_NAME} <commit-message>"
  exit 1
end

root_dir = File.expand_path('..', __dir__)
Dir.chdir(root_dir)

# 1. Quality gate
gate_script = File.join(root_dir, 'tools', 'check')
if File.exist?(gate_script)
  gate_out, gate_err, status = Open3.capture3(gate_script)
  unless status.success?
    puts gate_out unless gate_out.empty?
    puts gate_err unless gate_err.empty?
    exit 1
  end
end

# 2. Stage changes
_, _, s = Open3.capture3("git add -A")
unless s.success?
  warn "git add failed"
  exit 1
end

# 3. Commit
out, err, s = Open3.capture3("git commit -m #{msg.inspect}")
unless s.success?
  warn out unless out.empty?
  warn err unless err.empty?
  exit 1
end

# 4. Record .verified_head
head = `git rev-parse HEAD`.strip
File.write(File.join(root_dir, '.verified_head'), head)

puts "\e[32m✔ Successfully committed:\e[0m #{msg}"
exit 0
