#!/usr/bin/env ruby
# frozen_string_literal: true

require 'open3'

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

puts "\e[1;36m=== Quality Gate (#{proj_name}) ===\e[0m"

# 1. Syntax Check
puts "==> 1. Checking Ruby Syntax (ruby -cw)..."
files = Dir.glob('lib/**/*.rb') + Dir.glob('bin/*') + Dir.glob('tools/*') + Dir.glob('test/**/*.rb')
files = files.select { |f| File.file?(f) && (File.extname(f) == '.rb' || File.open(f, &:gets)&.start_with?('#!/usr/bin/env ruby')) }
files.each do |f|
  _, err, status = Open3.capture3("ruby -cw #{f}")
  unless status.success? && (err.empty? || err.strip == 'Syntax OK')
    clean_err = err.lines.reject { |l| l.strip == 'Syntax OK' }.join.strip
    if !clean_err.empty?
      puts "\e[31m✗ Syntax error in #{f}:\e[0m\n#{clean_err}"
      exit 1
    end
  end
end
puts "  \e[32m✔ Syntax OK across #{files.size} files\e[0m"

# 2. Sizing & Cognitive Complexity Metrics
puts "==> 2. Auditing Cognitive Complexity & Sizing..."
audit_bin = `which ruby-audit 2>/dev/null`.strip
audit_bin = File.expand_path('~/prog/standards/ruby/bin/ruby-audit') if audit_bin.empty?
run_cmd('Code Metrics Audit', "#{audit_bin} --quiet")

# 3. Style & Linting (RuboCop if configured)
if File.exist?('.rubocop.yml') && !`which rubocop 2>/dev/null`.strip.empty?
  puts "==> 3. Running RuboCop..."
  run_cmd('RuboCop', 'rubocop --parallel')
  puts "  \e[32m✔ RuboCop passed with 0 offenses\e[0m"
end

# 4. Test Suite Execution
test_files = Dir.glob('test/**/test_*.rb') + Dir.glob('test/**/*_test.rb')
if test_files.any?
  puts "==> 4. Running Test Suite..."
  if File.exist?('Rakefile') && File.read('Rakefile').include?('Rake::TestTask')
    run_cmd('Unit Tests', 'bundle exec rake test')
  else
    test_files.each do |tf|
      run_cmd("Test #{tf}", "ruby -Ilib:test #{tf}")
    end
  end
  puts "  \e[32m✔ Tests passed cleanly\e[0m"
end

puts "\n\e[32m✔ Quality Gate passed successfully!\e[0m\n\n"
exit 0
