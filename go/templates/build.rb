#!/usr/bin/env ruby
# frozen_string_literal: true

# tools/build for Go projects. Contract (see ~/prog/standards/README.md, "tools/build"):
#   - produces the artifact inside the repository; exits non-zero on failure
#   - never writes outside the repository tree (installing is tools/install's job)
#   - runs no tests or linters (that is tools/gate's job)
# Builds every package and, when main.go is at the root, writes the binary to bin/<project>.

ENV['PATH'] = "#{File.expand_path('~/.go/bin')}:#{File.expand_path('~/go/bin')}:#{ENV.fetch('PATH', '')}"
root_dir = File.expand_path('..', __dir__)
Dir.chdir(root_dir)
abort "\e[31m✗ tools/build: go.mod not found in #{root_dir}.\e[0m" unless File.exist?('go.mod')

puts '==> go build ./...'
abort "\e[31m✗ Build failed.\e[0m" unless system('go', 'build', './...')

if File.exist?('main.go')
  out = File.join('bin', File.basename(root_dir))
  puts "==> go build -o #{out} ."
  abort "\e[31m✗ Build failed.\e[0m" unless system('go', 'build', '-o', out, '.')
end
puts "\e[32m✔ Build OK\e[0m"
