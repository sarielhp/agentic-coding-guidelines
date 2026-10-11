# frozen_string_literal: true

require 'fileutils'
require 'json'
require 'minitest/autorun'
require 'open3'
require 'rbconfig'
require 'tmpdir'

class ToolFixture < Minitest::Test
  TEMPLATES = File.expand_path('../templates', __dir__)
  MOCK = <<~'RUBY'
    #!/usr/bin/env ruby
    # frozen_string_literal: true
    require 'json'
    require 'fileutils'
    tool = File.basename($PROGRAM_NAME)
    File.open(ENV.fetch('TRACE'), 'a') { |file| file.puts(JSON.generate([tool, *ARGV])) }
    if tool == 'git'
      abort 'injected git failure' if ENV['FAIL_GIT'] == ARGV.first
      if ENV['REMOTE_MISMATCH'] == '1' && ARGV.first == 'ls-remote'
        puts "#{'0' * 40}\trefs/heads/main"
        exit
      end
      exec(ENV.fetch('REAL_GIT'), *ARGV)
    end
    abort 'analyzer crashed' if ENV['FAIL_TOOL'] == tool
    if tool == 'staticcheck'
      puts ENV['FINDINGS'] if ENV['FINDINGS']
      exit(ENV.fetch('ANALYZER_STATUS', '0').to_i)
    end
    if tool == 'go-audit' && ENV['AUDIT_FINDINGS']
      puts ENV['AUDIT_FINDINGS']
      warn 'Error: 0 file(s) and 1 function(s) exceed their hard limit in strict mode.'
      exit 1
    end
    if ENV['USE_REAL_GO'] == '1' && %w[go gofmt].include?(tool)
      exit if tool == 'go' && ARGV.any? { |arg| arg.start_with?('-vettool=') }
      exec(ENV.fetch(tool == 'go' ? 'REAL_GO' : 'REAL_GOFMT'), *ARGV)
    end
    if tool == 'go'
      puts '{}' if ARGV.first == 'env'
      puts 'main' if ARGV == ['list', '-f', '{{.Name}}', '.']
      puts "#{Dir.pwd}|#{ENV.fetch('EMBED_FILES', '')}" if ARGV.first == 'list' && ARGV.last == './...'
      if ARGV.first == 'build' && ARGV.include?('-o')
        target = ARGV[ARGV.index('-o') + 1]
        File.binwrite(target, "built #{File.read('VERSION').strip}")
        File.chmod(0o755, target)
      end
    end
  RUBY

  def setup
    @tmp = Dir.mktmpdir('go-tools-')
    @repo = File.join(@tmp, 'app')
    @bin = File.join(@tmp, 'mock-bin')
    FileUtils.mkdir_p([@repo, @bin, File.join(@repo, 'tools')])
    @real_git = find_command('git')
    @env = fixture_environment
    copy_templates
    write('go.mod', "module example.test/fixture\n\ngo 1.26\n")
    write('main.go', "package main\n\nfunc main() {}\n")
    write('VERSION', "1.2.3\n")
    write('.gitignore', "/bin/\n/fixture\n")
    command('init', '-b', 'main')
    command('config', 'user.name', 'Fixture')
    command('config', 'user.email', 'fixture@example.test')
    command('add', '-A')
    command('commit', '-m', 'initial')
    reset_trace
  end

  def teardown
    FileUtils.remove_entry(@tmp) if @tmp && File.directory?(@tmp)
  end

  def fixture_environment
    %w[go gofmt staticcheck go-audit govulncheck gocritic shadow revive dupl git].each do |tool|
      File.write(File.join(@bin, tool), MOCK)
      File.chmod(0o755, File.join(@bin, tool))
    end
    { 'PATH' => "#{@bin}#{File::PATH_SEPARATOR}#{ENV.fetch('PATH')}", 'TRACE' => File.join(@tmp, 'trace'),
      'REAL_GIT' => @real_git, 'REAL_GO' => find_command('go'), 'REAL_GOFMT' => find_command('gofmt'),
      'GOBIN' => nil, 'GOPATH' => nil, 'GOWORK' => 'off', 'GOTOOLCHAIN' => 'local',
      'GOCACHE' => File.join(@tmp, 'cache'), 'GOMODCACHE' => File.join(@tmp, 'module-cache'), 'GOPROXY' => 'off',
      'XDG_CACHE_HOME' => File.join(@tmp, 'analyzer-cache') }
  end

  def find_command(name)
    ENV.fetch('PATH').split(File::PATH_SEPARATOR).map { |dir| File.join(dir, name) }
       .find { |path| File.file?(path) && File.executable?(path) } || raise("missing fixture tool #{name}")
  end

  def copy_templates
    Dir.glob(File.join(TEMPLATES, '*.rb')).each do |source|
      name = File.basename(source)
      name = name.delete_suffix('.rb') unless %w[settings.rb tooling.rb].include?(name)
      FileUtils.cp(source, File.join(@repo, 'tools', name))
      File.chmod(0o755, File.join(@repo, 'tools', name))
    end
  end

  def write(path, contents)
    FileUtils.mkdir_p(File.dirname(File.join(@repo, path)))
    File.write(File.join(@repo, path), contents)
  end

  def setting(name, value)
    path = File.join(@repo, 'tools/settings.rb')
    content = File.read(path)
    content.sub!(/^  #{Regexp.escape(name)} = .*$/, "  #{name} = #{value}")
    File.write(path, content)
  end

  def command(*args)
    out, err, status = Open3.capture3(@env, @real_git, *args, chdir: @repo)
    assert status.success?, "git #{args.inspect}: #{out}#{err}"
    out
  end

  def invoke(name, *, env: {})
    Open3.capture3(@env.merge(env), File.join(@repo, 'tools', name), *, chdir: @repo)
  end

  def succeeds(name, *, env: {})
    out, err, status = invoke(name, *, env: env)
    assert status.success?, "#{name}: #{out}#{err}"
    out
  end

  def fails(name, *, env: {})
    out, err, status = invoke(name, *, env: env)
    refute status.success?, "unexpected success: #{out}#{err}"
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
    command('init', '--bare', bare)
    command('remote', 'add', 'origin', bare)
    command('push', '-u', 'origin', 'main')
    bare
  end

  def record_path(name = 'verification')
    File.join(@repo, '.git', "tooling-#{name}.json")
  end

  def checkpoint
    command('add', '-A')
    command('commit', '-m', 'fixture settings')
    reset_trace
  end
end
