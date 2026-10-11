# frozen_string_literal: true

module Language
  SECTION = /^\s*\[([^\]]+)\]\s*(?:#.*)?$/
  VERSION_ASSIGNMENT = /^\s*version\s*=\s*(?<quote>['"])(?<value>[^'"\n]+)\k<quote>\s*(?:#.*)?$/
  FULL_TOOLS = %w[cargo-audit cargo-deny cargo-machete cargo-geiger].freeze

  module_function

  def name
    'Rust'
  end

  def setup
    raise 'Cargo.toml missing' unless File.file?('Cargo.toml')
    raise 'declare target directory through TARGET_DIR, not BUILD_ARGS' if ToolSettings::BUILD_ARGS.any? do |arg|
      arg.start_with?('--target-dir')
    end

    ENV['CARGO_TARGET_DIR'] = Tooling.contained_path(ToolSettings::TARGET_DIR)
  end

  def tool_paths
    [ENV.fetch('CARGO_HOME', File.expand_path('~/.cargo')) + '/bin']
  end

  def required_inputs
    ['Cargo.toml', 'Cargo.lock', ToolSettings::VERSION_FILE, ToolSettings::BUMP_STATE]
  end

  def verification_tools
    %w[cargo rustc rustfmt cargo-clippy clippy-driver rust-audit] + FULL_TOOLS
  end

  def environment
    version = Tooling.query(Tooling.executable('rustc'), '--version', '--verbose')
    [version, ENV.to_h.select { |key, _| key.start_with?('CARGO', 'RUST', 'CC', 'CXX') }]
  end

  def preflight(full)
    (%w[cargo rust-audit] + (full ? FULL_TOOLS : [])).each { |tool| Tooling.executable(tool) }
  end

  def cargo(operation, *, locked: true)
    flags = ['--offline', '--target-dir', Tooling.contained_path(ToolSettings::TARGET_DIR)]
    flags << '--locked' if locked
    Tooling.run(Tooling.executable('cargo'), operation, *flags, *ToolSettings::BUILD_ARGS, *)
  end

  def artifacts
    return ToolSettings::ARTIFACTS unless ToolSettings::ARTIFACTS.nil?

    raw = Tooling.query(Tooling.executable('cargo'), 'metadata', '--offline', '--no-deps', '--format-version', '1')
    metadata = JSON.parse(raw)
    members = metadata.fetch('workspace_members')
    metadata.fetch('packages').select { |package| members.include?(package.fetch('id')) }.flat_map do |package|
      package.fetch('targets').select { |target| target.fetch('kind').include?('bin') }.map do |target|
        File.join(ToolSettings::TARGET_DIR, 'release', target.fetch('name'))
      end
    end
  end

  def build
    Tooling.contained_path(ToolSettings::TARGET_DIR)
    outputs = artifacts.map { |path| Tooling.contained_path(path) }
    cargo('build', '--release')
    outputs.each do |path|
      Tooling.contained_path(path)
      raise "build artifact missing or not executable: #{path}" unless File.file?(path) && File.executable?(path)
    end
    puts 'Build passed'
  end

  def lint
    preflight(false)
    Tooling.run(Tooling.executable('cargo'), 'fmt', '--all', '--check')
    cargo('clippy', '--all-targets', '--', '-D', 'warnings')
    Tooling.run(Tooling.executable('rust-audit'), '--quiet', '--strict', '.')
    puts 'Lint passed'
  end

  def test
    cargo('test', '--all-targets')
  end

  def gate_start; end

  def gate_finish
    Tooling.script('build')
  end

  def deep_review
    Tooling.run(Tooling.executable('cargo-audit'), 'audit')
    Tooling.run(Tooling.executable('cargo-deny'), 'deny', 'check')
    Tooling.run(Tooling.executable('cargo-machete'), 'machete')
    Tooling.run(Tooling.executable('cargo-geiger'), 'geiger', '--locked', '--offline', '--all-targets')
  end

  def version_match
    path = ToolSettings::VERSION_FILE
    Tooling.contained_path(path)
    raise "release manifest missing: #{path}" unless File.file?(path)

    offset = 0
    section = nil
    File.read(path).each_line do |line|
      section = line.match(SECTION)[1] if line.match?(SECTION)
      match = line.match(VERSION_ASSIGNMENT) if section == ToolSettings::VERSION_SECTION
      return [path, match[:value], offset + match.begin(:value), match[:value].length] if match

      offset += line.length
    end
    raise "no literal version in [#{ToolSettings::VERSION_SECTION}] of #{path}; configure the release manifest/section"
  end

  def version
    version_match.first(2)
  end

  def update_version(updated)
    path, _, start, length = version_match
    contents = File.read(path)
    contents[start, length] = updated
    File.write(path, contents)
    File.write(Tooling.contained_path('VERSION'), "#{updated}\n") if File.file?('VERSION')
    return unless File.file?('CHANGELOG.md')

    contents = File.read('CHANGELOG.md')
    contents.sub!('## [Unreleased]', "## [Unreleased]\n\n## [#{updated}] - #{Date.today}")
    File.write(Tooling.contained_path('CHANGELOG.md'), contents)
  end

  def synchronize_version
    cargo('check', '--all-targets', locked: false)
  end

  def next_milestone
    path = Tooling.contained_path(ToolSettings::BUMP_STATE)
    state = File.file?(path) ? JSON.parse(File.read(path)) : { 'count' => 0 }
    count = state.fetch('count')
    raise 'invalid bump count; inspect bump state' unless count.is_a?(Integer) && count >= 0

    count + 1
  end

  def prepare_milestone(count)
    File.write(ToolSettings::BUMP_STATE, JSON.pretty_generate(count: count, version: version.last))
  end

  def milestone_checks(count)
    Tooling.run(*ToolSettings::BENCHMARK) if ToolSettings::BENCHMARK && (count % 5).zero?
    Tooling.run(*ToolSettings::DEEP_TEST) if ToolSettings::DEEP_TEST && (count % 20).zero?
  end
end
