#!/usr/bin/env ruby
# frozen_string_literal: true

require 'open3'

ENV['PATH'] = "#{File.expand_path('~/.go/bin')}:#{File.expand_path('~/go/bin')}:#{ENV['PATH']}"
root_dir = File.expand_path('..', __dir__)
Dir.chdir(root_dir)

proj_name = File.basename(root_dir)

def run_cmd(name, cmd)
  stdout, stderr, status = Open3.capture3(cmd)
  unless status.success?
    puts "\e[31m✗ #{name} failed!\e[0m"
    puts "\e[1mStdout:\e[0m" unless stdout.empty?
    puts stdout unless stdout.empty?
    puts "\e[1mStderr:\e[0m" unless stderr.empty?
    puts stderr unless stderr.empty?
    exit 1
  end
  [stdout, stderr]
end

puts "\e[1m=== Quality Gate (#{proj_name}) ===\e[0m"

# 1. Format
unformatted_out, _ = Open3.capture3("gofmt -s -l .")
unformatted = unformatted_out.lines.map(&:strip).reject(&:empty?)
if unformatted.any?
  _, err, status = Open3.capture3("gofmt -s -w .")
  if !status.success? && err.include?("read-only file system")
    puts "\e[31m✗ Formatting check failed! Files need gofmt:\e[0m\n#{unformatted.join("\n")}"
    exit 1
  elsif !status.success?
    puts "\e[31m✗ Formatting failed:\e[0m\n#{err}"
    exit 1
  end
end

# 2. Mod tidy
run_cmd("Go mod tidy", "go mod tidy -diff") if File.exist?('go.mod')

# 3. Vet
run_cmd("Go vet", "go vet ./...")

# 4. Staticcheck (baseline aware if baseline file exists)
staticcheck_bin = `which staticcheck 2>/dev/null`.strip
if !staticcheck_bin.empty?
  out, _, _ = Open3.capture3("staticcheck ./...")
  baseline_file = File.join(root_dir, 'tools', 'staticcheck-baseline.txt')
  if File.exist?(baseline_file)
    baseline_lines = File.read(baseline_file).lines.map(&:strip)
    normalize_issue = ->(l) { l.sub(/:\d+:\d+:/, ':') }
    baseline_set = baseline_lines.map(&normalize_issue).to_set
    current_lines = out.lines.map(&:strip).reject(&:empty?)
    new_issues = current_lines.reject { |l| baseline_set.include?(normalize_issue.call(l)) }
    if new_issues.any?
      puts "\e[31m✗ Staticcheck found #{new_issues.size} new issue(s):\e[0m"
      puts new_issues.join("\n")
      exit 1
    end
  elsif !out.strip.empty?
    puts "\e[31m✗ Staticcheck found issue(s):\e[0m"
    puts out
    exit 1
  end
end

# 5. Cognitive complexity and line audit
audit_bin = `which go-audit 2>/dev/null`.strip
audit_cmd = if !audit_bin.empty?
              "go-audit --quiet"
            elsif File.exist?(File.join(root_dir, 'tools', 'audit_lines'))
              "#{File.join(root_dir, 'tools', 'audit_lines')} --quiet"
            end

if audit_cmd
  stdout, _ = run_cmd("Line & complexity audit", audit_cmd)
  puts stdout.strip unless stdout.strip.empty?
end

# 6. Go test
run_cmd("Go test", "go test -v ./...")

# 7. Build
bin_name = proj_name
out, err, s = Open3.capture3("go build -o /dev/null .")
unless s.success?
  puts "\e[31m✗ Build failed!\e[0m"
  puts err
  exit 1
end

# 8. Version consistency (if VERSION file exists)
version_file = File.join(root_dir, 'VERSION')
if File.exist?(version_file)
  ver = File.read(version_file).strip
  main_file = File.join(root_dir, 'main.go')
  if File.exist?(main_file)
    main_content = File.read(main_file)
    if main_content =~ /Version\s*=\s*"([^"]+)"/
      code_ver = Regexp.last_match(1)
      if ver != code_ver
        puts "\e[31m✗ Version mismatch: VERSION=#{ver}, main.go=#{code_ver}\e[0m"
        exit 1
      end
    end
  end
end

puts "\e[32m✔ Quality gate passed!\e[0m"
exit 0
