#!/usr/bin/env ruby
# frozen_string_literal: true

require 'open3'

ENV['PATH'] = "#{File.expand_path('~/.cargo/bin')}:#{ENV['PATH']}"
root_dir = File.expand_path('..', __dir__)
Dir.chdir(root_dir)

proj_name = File.basename(root_dir)

def run_cmd(name, cmd)
  stdout, stderr, status = Open3.capture3(cmd)
  unless status.success?
    puts "\e[31m✗ #{name} failed!\e[0m"
    puts "\e[1mStdout:\e[0m\n#{stdout}" unless stdout.strip.empty?
    puts "\e[1mStderr:\e[0m\n#{stderr}" unless stderr.strip.empty?
    exit 1
  end
  [stdout, stderr]
end

puts "\e[1m=== Quality Gate (Rust: #{proj_name}) ===\e[0m"

# 1. Cargo fmt check
puts '--> [1/5] Cargo format check...'
unformatted_out, _, status = Open3.capture3('cargo fmt --check')
unless status.success?
  puts "\e[31m✗ Code formatting issues detected. Run `cargo fmt` to fix.\e[0m"
  puts unformatted_out unless unformatted_out.strip.empty?
  exit 1
end

# 2. Cargo clippy
puts '--> [2/5] Cargo clippy...'
run_cmd('Cargo clippy', 'cargo clippy --all-targets -- -D warnings')

# 3. Cognitive complexity & line audit (rust-audit)
puts '--> [3/5] Cognitive complexity & sizing audit...'
audit_bin = `which rust-audit 2>/dev/null`.strip
audit_cmd = if !audit_bin.empty?
              'rust-audit --quiet --strict'
            elsif File.exist?(File.join(root_dir, 'tools', 'rust-audit'))
              "#{File.join(root_dir, 'tools', 'rust-audit')} --quiet --strict"
            end

if audit_cmd
  stdout, _ = run_cmd('Complexity audit', audit_cmd)
  puts stdout.strip unless stdout.strip.empty?
else
  puts "  \e[33m[SKIP]\e[0m rust-audit not found in PATH or tools/"
end

# 4. Cargo tests
puts '--> [4/5] Cargo test suite...'
run_cmd('Cargo test', 'cargo test')

# 5. Check all targets
puts '--> [5/5] Cargo check (all targets)...'
run_cmd('Cargo check', 'cargo check --all-targets')

# 6. Version consistency check (if Cargo.toml and VERSION exist)
version_file = File.join(root_dir, 'VERSION')
cargo_toml = File.join(root_dir, 'Cargo.toml')
if File.exist?(version_file) && File.exist?(cargo_toml)
  ver = File.read(version_file).strip
  toml_ver = File.read(cargo_toml)[/^version\s*=\s*["']([^"']+)["']/, 1]
  if toml_ver && ver != toml_ver
    puts "\e[31m✗ Version mismatch: VERSION=#{ver}, Cargo.toml=#{toml_ver}\e[0m"
    exit 1
  end
end

puts "\e[32m✔ Rust quality gate passed!\e[0m"
exit 0
