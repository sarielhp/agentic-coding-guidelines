#!/usr/bin/env ruby
# frozen_string_literal: true

require 'open3'

# tools/build for Ruby projects. Contract (see ~/prog/standards/README.md, "tools/build"):
#   - produces or validates the artifact inside the repository; exits non-zero on failure
#   - never writes outside the repository tree (installing is tools/install's job)
#   - runs no tests or linters (that is tools/gate's job)
# The artifact of an interpreted language is the source itself, so build == syntax check.

root_dir = File.expand_path('..', __dir__)
Dir.chdir(root_dir)

def ruby_source?(path)
  return false if File.symlink?(path) || !File.file?(path)
  return true if path.end_with?('.rb') || File.basename(path) == 'Rakefile'

  first = File.open(path, &:gets).to_s
  first.start_with?('#!') && first.include?('ruby')
end

files = (Dir.glob('bin/*') + Dir.glob('lib/**/*.rb') + Dir.glob('tools/*') + Dir.glob('*.rb') + Dir.glob('Rakefile'))
        .select { |f| ruby_source?(f) }
abort "\e[31m✗ tools/build: no Ruby sources found under bin/, lib/, tools/ or the root.\e[0m" if files.empty?

broken = files.reject do |f|
  _, err, status = Open3.capture3('ruby', '-cw', f)
  noise = err.lines.reject { |l| l.strip == 'Syntax OK' }.join
  puts "\e[31m✗ #{f}\e[0m\n#{noise}" unless status.success? && noise.empty?
  status.success? && noise.empty?
end

abort "\e[31m✗ Build failed: #{broken.size} file(s) with syntax errors or warnings.\e[0m" unless broken.empty?
puts "\e[32m✔ Build OK: #{files.size} Ruby file(s) parse cleanly (ruby -cw)\e[0m"
