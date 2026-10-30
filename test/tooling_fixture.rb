# frozen_string_literal: true

require 'fileutils'
require 'json'
require 'minitest/autorun'
require 'open3'
require 'rbconfig'
require 'tmpdir'

class ToolingFixture < Minitest::Test
  ROOT = File.expand_path('..', __dir__)
  MOCK = <<~'RUBY'
    # frozen_string_literal: true
    require 'json'
    require 'fileutils'
    tool = File.basename($PROGRAM_NAME)
    File.open(ENV.fetch('TRACE'), 'a') { |file| file.puts(JSON.generate([tool, *ARGV])) }
    abort 'injected failure' if ENV['FAIL'] == "#{tool}:#{ARGV.first}" || ENV['FAIL'] == tool
    if tool == 'git'
      if ARGV.first == 'ls-remote' && ENV['REMOTE_MISMATCH'] == '1'
        puts "#{'0' * 40}\t#{ARGV.last}"
        exit
      end
      exec(ENV.fetch('REAL_GIT'), *ARGV)
    end
    if tool == 'cargo' && ENV['REAL_LANGUAGE'] == '1'
      exec(ENV.fetch('REAL_CARGO'), *ARGV)
    end
    if tool == 'rustc'
      exec(ENV.fetch('REAL_RUSTC'), *ARGV) if ENV['REAL_LANGUAGE'] == '1'
      puts 'rustc fixture 1.0'
    end
    if tool == 'cargo'
      version = File.read('Cargo.toml')[/version\s*=\s*"([^\"]+)"/, 1]
      if ARGV.first == 'metadata'
        targets = ENV['LIBRARY'] == '1' ? [] : [{ name: 'fixture', kind: ['bin'] }]
        puts JSON.generate(workspace_members: ['fixture'], packages: [{ id: 'fixture', targets: targets }])
      end
      if ARGV.first == 'build'
        dir = ARGV[ARGV.index('--target-dir') + 1]
        FileUtils.mkdir_p(File.join(dir, 'release'))
        File.binwrite(File.join(dir, 'release/fixture'), "built #{version}")
        File.chmod(0o755, File.join(dir, 'release/fixture'))
      end
      File.write('Cargo.lock', "version #{version}\n") if ARGV.first == 'check' && !ARGV.include?('--locked')
    end
    if tool == 'gh'
      puts(ENV.fetch('GH_RUNS', '[{"databaseId":7}]')) if ARGV.first(2) == %w[run list]
      abort 'CI run failed' if ARGV.first(2) == %w[run watch] && ENV['CI_FAIL'] == '1'
      puts 'https://github.com/owner/Fixture.jl/commit/c#comments' if ARGV.first == 'api'
    end
    if tool == 'flay'
      warn 'skipping file due to parser failure' if ENV['FLAY_SKIP'] == '1'
      puts "Total score (lower is better) = #{ENV.fetch('FLAY_SCORE', '0')}"
    end
  RUBY

  def setup
    @tmp = Dir.mktmpdir('language-tools-')
    @repo = File.join(@tmp, 'app with spaces')
    @bin = File.join(@tmp, 'mock-bin')
    FileUtils.mkdir_p([@repo, @bin, File.join(@repo, 'tools')])
    @env = fixture_environment
    copy_templates
    write('.gitignore', "/target/\n/.test-ran-*\n")
    send(:"initialize_#{self.class::LANGUAGE}")
    git('init', '-b', 'main')
    git('config', 'user.name', 'Fixture')
    git('config', 'user.email', 'fixture@example.test')
    git('add', '-A')
    git('commit', '-m', 'initial')
    reset_trace
  end

  def teardown
    FileUtils.remove_entry(@tmp) if @tmp && File.directory?(@tmp)
  end

  def executable(name)
    dirs = ENV.fetch('PATH').split(File::PATH_SEPARATOR) + [File.expand_path('~/.cargo/bin'), File.expand_path('~/.go/bin')]
    dirs.map { |dir| File.join(dir, name) }.find { |path| File.file?(path) && File.executable?(path) } ||
      raise("missing fixture tool #{name}")
  end

  def fixture_environment
    %w[git cargo rustc rust-audit cargo-audit cargo-deny cargo-machete ruby-audit rubocop bundle-audit flay
       bundle julia julia-audit julia-static-analysis gh].each do |tool|
      File.write(File.join(@bin, tool), "#!#{RbConfig.ruby}\n#{MOCK}")
      File.chmod(0o755, File.join(@bin, tool))
    end
    { 'PATH' => "#{@bin}#{File::PATH_SEPARATOR}#{ENV.fetch('PATH')}", 'TRACE' => File.join(@tmp, 'trace'),
      'REAL_GIT' => executable('git'), 'REAL_CARGO' => executable('cargo'), 'REAL_RUSTC' => executable('rustc'),
      'CARGO_TARGET_DIR' => File.join(@repo, 'target'), 'TEST_TRACE' => File.join(@tmp, 'test-trace'),
      'XDG_CACHE_HOME' => File.join(@tmp, 'cache'), 'RUBOCOP_CACHE_ROOT' => File.join(@tmp, 'rubocop-cache'),
      'RUSTUP_TOOLCHAIN' => nil }
  end

  def copy_templates
    Dir.glob(File.join(ROOT, self.class::LANGUAGE, 'templates/*.rb')).each do |source|
      name = File.basename(source)
      name = name.delete_suffix('.rb') unless %w[settings.rb tooling.rb language.rb].include?(name)
      target = File.join(@repo, 'tools', name)
      FileUtils.cp(source, target)
      File.chmod(0o755, target)
    end
  end

  def initialize_rust
    write('Cargo.toml', "[package]\nname = \"fixture\"\nversion = \"1.2.3\"\nedition = \"2024\"\n")
    write('Cargo.lock', "version 1.2.3\n")
    write('src/main.rs', "fn main() {}\n")
  end

  def initialize_ruby
    write('bin/fixture', "#!/usr/bin/env ruby\n# frozen_string_literal: true\n\nVERSION = '1.2.3'\nputs VERSION if ARGV == ['--version']\n")
    File.chmod(0o755, File.join(@repo, 'bin/fixture'))
    write('.rubocop.yml', File.read(File.join(ROOT, 'ruby/templates/dot_rubocop.yml')))
    write('.ruby-version', "#{RUBY_VERSION}\n")
  end

  # A registered-package layout. RELEASE_TAG is turned on so the shared
  # lifecycle contract, which checks the pushed tag, applies unchanged; the
  # default (no tag, TagBot tags) is covered by the Julia language tests.
  def initialize_julia
    write('Project.toml', <<~TOML)
      name = "Fixture"
      uuid = "8f2b7c1e-1d4a-4c8e-9a3b-0f6e5d4c3b2a"
      authors = ["Fixture"]
      version = "1.2.3"

      [compat]
      julia = "1.10"
    TOML
    write('src/Fixture.jl', "module Fixture\nend\n")
    write('bin/fixture', "#!/usr/bin/env julia\nprintln(\"fixture\")\n")
    File.chmod(0o755, File.join(@repo, 'bin/fixture'))
    setting('ARTIFACTS', "['bin/fixture'].freeze")
    setting('RELEASE_TAG', 'true')
  end

  def write(path, content)
    FileUtils.mkdir_p(File.dirname(File.join(@repo, path)))
    File.write(File.join(@repo, path), content)
  end

  def setting(name, value)
    path = File.join(@repo, 'tools/settings.rb')
    content = File.read(path)
    content.sub!(/^  #{Regexp.escape(name)} = .*$/, "  #{name} = #{value}")
    File.write(path, content)
  end

  def git(*args)
    out, err, status = Open3.capture3(@env, @env.fetch('REAL_GIT'), *args, chdir: @repo)
    assert status.success?, "git #{args.inspect}: #{out}#{err}"
    out
  end

  def invoke(name, *, env: {})
    Open3.capture3(@env.merge(env), [File.join(@repo, 'tools', name), name], *, chdir: @repo)
  end

  def succeeds(name, *, env: {})
    out, err, status = invoke(name, *, env: env)
    assert status.success?, "#{name}: #{out}#{err}"
    out
  end

  def fails(name, *, env: {})
    out, err, status = invoke(name, *, env: env)
    refute status.success?, "unexpected success #{name}: #{out}#{err}"
    "#{out}#{err}"
  end

  def trace
    File.readlines(@env.fetch('TRACE')).map { |line| JSON.parse(line) }
  end

  def reset_trace
    File.write(@env.fetch('TRACE'), '')
  end

  def add_remote
    bare = File.join(@tmp, 'remote.git')
    git('init', '--bare', bare)
    git('remote', 'add', 'origin', bare)
    git('push', '-u', 'origin', 'main')
    bare
  end

  def marker(name = 'verification')
    File.join(@repo, '.git', "tooling-#{name}.json")
  end

  def checkpoint
    git('add', '-A')
    git('commit', '-m', 'fixture settings')
    reset_trace
  end

  def artifact
    self.class::LANGUAGE == 'rust' ? 'target/release/fixture' : 'bin/fixture'
  end

  AUDITORS = { 'rust' => 'rust-audit', 'ruby' => 'ruby-audit', 'julia' => 'julia-audit' }.freeze

  def auditor
    AUDITORS.fetch(self.class::LANGUAGE)
  end

  # A trace row that only the full gate's deep review produces.
  def deep_review_row?(row)
    %w[cargo-audit flay].include?(row.first) || (row.first == 'julia-static-analysis' && row.include?('--jet'))
  end

  def current_version
    file = { 'rust' => 'Cargo.toml', 'ruby' => 'bin/fixture', 'julia' => 'Project.toml' }.fetch(self.class::LANGUAGE)
    File.read(File.join(@repo, file))[/\d+\.\d+\.\d+/]
  end
end
