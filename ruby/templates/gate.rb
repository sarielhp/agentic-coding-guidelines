#!/usr/bin/env ruby
# frozen_string_literal: true

require 'open3'

# Tier 1 quality gate for Ruby projects: build (syntax), ruby-audit, RuboCop, tests.
# Canonical name is tools/gate; keep tools/check as a symlink for Makefile compatibility.

root_dir = File.expand_path('..', __dir__)
Dir.chdir(root_dir)
proj_name = File.basename(root_dir)

def run_cmd(name, *cmd)
  stdout, stderr, status = Open3.capture3(*cmd)
  return [stdout, stderr] if status.success?

  puts "\e[31m✗ #{name} failed!\e[0m"
  puts "\e[1mStdout:\e[0m\n#{stdout}" unless stdout.strip.empty?
  puts "\e[1mStderr:\e[0m\n#{stderr}" unless stderr.strip.empty?
  exit 1
end

puts "\e[1;36m=== Quality Gate (#{proj_name}) ===\e[0m"

# 1. Build: syntax validation lives in tools/build so it is defined exactly once.
puts '==> 1. Build / syntax validation (tools/build)...'
build = File.join(root_dir, 'tools', 'build')
abort "\e[31m✗ tools/build is missing. Copy ~/prog/standards/ruby/templates/build.rb to tools/build.\e[0m" unless File.executable?(build)
out, = run_cmd('Build', build)
puts out.lines.map { |l| "  #{l}" }.join

# 2. Sizing & cognitive complexity metrics
puts '==> 2. Auditing Cognitive Complexity & Sizing...'
audit_bin = `which ruby-audit 2>/dev/null`.strip
audit_bin = File.expand_path('~/prog/standards/ruby/bin/ruby-audit') if audit_bin.empty?
run_cmd('Code Metrics Audit', audit_bin, '--quiet')

# 3. Style & linting (RuboCop, when the project carries a .rubocop.yml)
if File.exist?('.rubocop.yml') && !`which rubocop 2>/dev/null`.strip.empty?
  puts '==> 3. Running RuboCop...'
  run_cmd('RuboCop', 'rubocop', '--parallel')
  puts "  \e[32m✔ RuboCop passed with 0 offenses\e[0m"
end

# 4. Test suite
test_files = Dir.glob('test/**/test_*.rb') + Dir.glob('test/**/*_test.rb')
if test_files.any?
  puts '==> 4. Running Test Suite...'
  if File.exist?('Rakefile') && File.read('Rakefile').include?('Rake::TestTask')
    run_cmd('Unit Tests', 'bundle', 'exec', 'rake', 'test')
  else
    test_files.each { |tf| run_cmd("Test #{tf}", 'ruby', '-Ilib:test', tf) }
  end
  puts "  \e[32m✔ Tests passed cleanly (#{test_files.size} file(s))\e[0m"
end

puts "\n\e[32m✔ Quality Gate passed successfully!\e[0m\n\n"
