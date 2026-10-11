# frozen_string_literal: true

require 'open3'

module AnalysisSupport
  module_function

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

  def protect_target_dir
    root = Dir.pwd
    path = File.expand_path(ENV.fetch('CARGO_TARGET_DIR', 'target'))
    raise 'Cargo artifact directory must remain inside the analyzed repository' unless path.start_with?("#{root}/")

    ancestor = path
    ancestor = File.dirname(ancestor) until File.exist?(ancestor) || File.symlink?(ancestor)
    resolved = File.realpath(ancestor)
    raise 'Cargo artifact symlink escapes analyzed repository' unless resolved == root || resolved.start_with?("#{root}/")

    ENV['CARGO_TARGET_DIR'] = path
  end
end
