#!/usr/bin/env ruby
# frozen_string_literal: true

require 'fileutils'
require 'optparse'

# Installs every executable in bin/ into ~/bin (copy by default, --link for symlinks).
# Runs tools/build first. Writes only inside the destination directory.
# Usage: ./tools/install [--link] [--dest DIR] [script names...]

options = { link: false, dest: File.expand_path('~/bin') }
OptionParser.new do |opts|
  opts.banner = 'Usage: ./tools/install [options] [script names...]'
  opts.on('--link', 'Symlink into the destination instead of copying') { options[:link] = true }
  opts.on('--dest DIR', 'Destination directory (default: ~/bin)') { |d| options[:dest] = File.expand_path(d) }
  opts.on('-h', '--help', 'Show this help') do
    puts opts
    exit 0
  end
end.parse!

root_dir = File.expand_path('..', __dir__)
build = File.join(root_dir, 'tools', 'build')
abort "\e[31m❌ tools/build failed; nothing installed.\e[0m" if File.executable?(build) && !system(build)

scripts = Dir.glob(File.join(root_dir, 'bin', '*')).select { |f| File.file?(f) && File.executable?(f) }
scripts.select! { |f| ARGV.include?(File.basename(f)) } unless ARGV.empty?
abort "\e[31m❌ Nothing executable found in bin/#{" matching #{ARGV.join(', ')}" unless ARGV.empty?}.\e[0m" if scripts.empty?

FileUtils.mkdir_p(options[:dest])
scripts.each do |script|
  target = File.join(options[:dest], File.basename(script))
  FileUtils.rm_f(target)
  if options[:link]
    FileUtils.ln_s(script, target)
  else
    FileUtils.cp(script, target)
    FileUtils.chmod('u+x,go+rx', target)
  end
  # Only probe scripts that declare a --version flag; running an arbitrary script is not safe.
  version = File.read(script).include?("'--version'") ? `#{target} --version 2>/dev/null`.strip : ''
  puts "==> Installed #{options[:link] ? 'symlink' : 'copy'} #{target}#{"  (#{version})" unless version.empty?}"
end

path_dirs = ENV.fetch('PATH', '').split(File::PATH_SEPARATOR)
warn "Note: #{options[:dest]} is not in your PATH." unless path_dirs.include?(options[:dest])
