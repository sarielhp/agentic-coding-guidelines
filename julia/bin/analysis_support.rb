# frozen_string_literal: true

require 'open3'

# Shared helpers for the Julia tooling wrappers: locating executables, running
# them without a shell, and discovering Julia sources.
module AnalysisSupport
  module_function

  IGNORED_DIRECTORIES = %w[.git vendor junk deps .julia node_modules .bws build].freeze

  def executable(name)
    if name.include?(File::SEPARATOR)
      path = File.expand_path(name)
      raise "required analyzer missing: #{name}" unless File.file?(path) && File.executable?(path)

      return path
    end
    path = ENV.fetch('PATH', '').split(File::PATH_SEPARATOR).map { |dir| File.join(dir, name) }
              .find { |file| File.file?(file) && File.executable?(file) }
    raise "required analyzer missing: #{name}; bootstrap separately with authorization" unless path

    File.expand_path(path)
  end

  def capture(*args)
    Open3.capture3([args.first, args.first], *args.drop(1))
  rescue SystemCallError => e
    raise "cannot execute analyzer: #{e.message}"
  end

  def run(name, *)
    out, err, status = capture(executable(name), *)
    $stdout.write(out)
    $stderr.write(err)
    raise "#{name} failed (#{status.exitstatus || status.termsig})" unless status.success?

    out
  end

  def julia_script?(path)
    first_line = File.open(path, 'rb') { |file| file.gets(64) }.to_s
    first_line.start_with?('#!') && first_line.include?('julia')
  end

  def ignored?(path)
    path.split('/').intersect?(IGNORED_DIRECTORIES)
  end

  def julia_files(paths)
    paths.flat_map { |path| File.directory?(path) ? Dir.glob(File.join(path, '**', '*')) : Dir.glob(path) }
         .uniq.sort.select do |path|
      next false unless File.file?(path) && !File.symlink?(path)
      next false if ignored?(path)

      File.extname(path) == '.jl' || julia_script?(path)
    end
  end

  # Nearest Julia project directory (the one holding Project.toml) above a path.
  def project_root(path)
    expanded = File.expand_path(path)
    directory = File.directory?(expanded) ? expanded : File.dirname(expanded)
    loop do
      return directory if File.file?(File.join(directory, 'Project.toml'))
      return nil if File.dirname(directory) == directory

      directory = File.dirname(directory)
    end
  end
end
