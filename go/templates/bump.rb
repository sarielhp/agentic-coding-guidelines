#!/usr/bin/env ruby
# frozen_string_literal: true

require 'open3'

root_dir = File.expand_path('..', __dir__)
Dir.chdir(root_dir)

version_file = File.join(root_dir, 'VERSION')
unless File.exist?(version_file)
  warn "Error: VERSION file not found at #{version_file}"
  exit 1
end

current_version = File.read(version_file).strip
parts = current_version.split('.').map(&:to_i)
while parts.size < 3
  parts << 0
end
parts[-1] += 1
new_version = parts.join('.')

# Update VERSION file
File.write(version_file, "#{new_version}\n")

# Update main.go Version literal if present
main_go = File.join(root_dir, 'main.go')
if File.exist?(main_go)
  content = File.read(main_go)
  content.sub!(/(Version\s*=\s*)"[^"]+"/, "\\1\"#{new_version}\"")
  File.write(main_go, content)
  Open3.capture3("gofmt -s -w #{main_go}")
end

# Check if quality gate can be skipped via .verified_head
verified_head_file = File.join(root_dir, '.verified_head')
can_skip_gate = false

if File.exist?(verified_head_file)
  verified_sha = File.read(verified_head_file).strip
  current_sha = `git rev-parse HEAD`.strip
  if verified_sha == current_sha
    status_out = `git status --porcelain`.strip
    modified_files = status_out.lines.map { |l| l.strip.split(/\s+/).last }
    allowed = ['VERSION', 'main.go']
    can_skip_gate = (modified_files - allowed).empty?
  end
end

gate_script = File.join(root_dir, 'tools', 'check')
if !can_skip_gate && File.exist?(gate_script)
  gate_out, gate_err, s = Open3.capture3(gate_script)
  unless s.success?
    warn "Quality gate failed during bump"
    warn gate_out unless gate_out.empty?
    warn gate_err unless gate_err.empty?
    exit 1
  end
end

# Stage and commit version bump
files_to_add = ['VERSION']
files_to_add << 'main.go' if File.exist?(main_go)
`git add #{files_to_add.join(' ')}`

commit_out, commit_err, s = Open3.capture3("git commit -m \"chore: bump version to #{new_version}\"")
unless s.success?
  warn "git commit failed during bump"
  warn commit_out unless commit_out.empty?
  warn commit_err unless commit_err.empty?
  exit 1
end

# Push to origin
push_out, push_err, s = Open3.capture3("git push")
unless s.success?
  warn "git push failed"
  warn push_out unless push_out.empty?
  warn push_err unless push_err.empty?
  exit 1
end

# Remove .verified_head after push
File.delete(verified_head_file) if File.exist?(verified_head_file)

# Install if make install is supported
if File.exist?(File.join(root_dir, 'Makefile')) && File.read(File.join(root_dir, 'Makefile')).include?('install:')
  install_out, install_err, s = Open3.capture3("make install")
  unless s.success?
    warn "make install failed during bump"
    warn install_out unless install_out.empty?
    warn install_err unless install_err.empty?
    exit 1
  end
end

puts "\e[32m✔ Bumped version to #{new_version} (committed, pushed, installed)\e[0m"
exit 0
