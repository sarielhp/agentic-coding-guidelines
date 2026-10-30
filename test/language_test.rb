# frozen_string_literal: true

require_relative 'tooling_fixture'

class RustLanguageTest < ToolingFixture
  LANGUAGE = 'rust'

  def real_cargo(*)
    out, err, status = Open3.capture3(@env.merge('REAL_LANGUAGE' => '1'), @env.fetch('REAL_CARGO'), *, chdir: @repo)
    assert status.success?, "#{out}#{err}"
  end

  def test_real_binary_library_and_workspace_builds
    FileUtils.rm(File.join(@repo, 'Cargo.lock'))
    real_cargo('generate-lockfile', '--offline')
    setting('TOOLS', "{ 'rust-audit' => '#{ROOT}/rust/bin/rust-audit' }.freeze")
    succeeds('gate', env: { 'REAL_LANGUAGE' => '1' })
    assert File.executable?(File.join(@repo, 'target/release/fixture'))
    FileUtils.rm(File.join(@repo, 'src/main.rs'))
    write('src/lib.rs', "pub fn answer() -> u32 { 42 }\n")
    succeeds('build', env: { 'REAL_LANGUAGE' => '1' })
    write('Cargo.toml', "[workspace]\nmembers = [\"member\"]\nresolver = \"3\"\n\n[workspace.package]\nversion = \"1.2.3\"\n")
    write('member/Cargo.toml', "[package]\nname = \"member\"\nversion.workspace = true\nedition = \"2024\"\n")
    write('member/src/main.rs', "fn main() {}\n")
    setting('VERSION_SECTION', "'workspace.package'")
    real_cargo('generate-lockfile', '--offline')
    succeeds('build', env: { 'REAL_LANGUAGE' => '1' })
    assert File.executable?(File.join(@repo, 'target/release/member'))
    checkpoint
    add_remote
    succeeds('bump', env: { 'REAL_LANGUAGE' => '1' })
    assert_equal '1.2.4', current_version
    assert_match(/version = "1.2.4"/, File.read(File.join(@repo, 'Cargo.lock')))
  end

  def test_artifacts_and_version_auxiliaries_cannot_escape_repository
    setting('TARGET_DIR', @tmp.inspect)
    assert_match(/inside repository/, fails('build'))
    setting('TARGET_DIR', "'target'")
    File.symlink(@tmp, File.join(@repo, 'target'))
    assert_match(/symlink/, fails('build'))
    FileUtils.rm(File.join(@repo, 'target'))
    external = File.join(@tmp, 'external-version')
    File.write(external, 'unchanged')
    File.symlink(external, File.join(@repo, 'VERSION'))
    checkpoint
    add_remote
    assert_match(/symlink/, fails('bump'))
    assert_equal 'unchanged', File.read(external)
    refute(trace.any? { |row| row[1] == 'push' })
  end

  def test_failed_lock_update_stops_checks_and_milestone_failure_stops_publish
    setting('BENCHMARK', "[#{RbConfig.ruby.inspect}, '-e', 'exit 1'].freeze")
    write('.bump_state.json', JSON.generate(count: 4))
    checkpoint
    add_remote
    fails('bump', env: { 'FAIL' => 'cargo:check' })
    refute(trace.any? { |row| row.first == 'cargo-audit' })
    reset_trace
    fails('bump', '--resume')
    assert_equal 5, JSON.parse(File.read(File.join(@repo, '.bump_state.json'))).fetch('count')
    refute(trace.any? { |row| row[1] == 'push' })
    setting('BENCHMARK', 'nil')
    succeeds('bump', '--resume')
    assert_equal '1.2.4', current_version
  end

  def test_twentieth_milestone_and_invalid_state
    write('.bump_state.json', JSON.generate(count: 'bad'))
    checkpoint
    add_remote
    assert_match(/invalid bump count/, fails('bump'))
    assert_equal '1.2.3', current_version
    setting('DEEP_TEST', "[#{RbConfig.ruby.inspect}, '-e', 'exit 1'].freeze")
    write('.bump_state.json', JSON.generate(count: 19))
    checkpoint
    fails('bump')
    assert_equal 20, JSON.parse(File.read(File.join(@repo, '.bump_state.json'))).fetch('count')
    refute(trace.any? { |row| row[1] == 'push' })
  end

  def test_declared_output_must_exist_after_build
    setting('ARTIFACTS', "['target/release/missing'].freeze")
    assert_match(/artifact missing/, fails('build'))
    refute File.exist?(marker)
    assert_match(/only supported/, fails('install', '--link'))
    refute(trace.any? { |row| row[1] == 'push' })
  end
end

class RubyLanguageTest < ToolingFixture
  LANGUAGE = 'ruby'

  def test_all_minitest_files_run_once_and_failures_are_not_masked
    %w[first second].each do |name|
      write("test/#{name}_test.rb", <<~RUBY)
        # frozen_string_literal: true
        require 'minitest/autorun'
        class #{name.capitalize}Test < Minitest::Test
          def test_example
            File.open(ENV.fetch('TEST_TRACE'), 'a') { |file| file.puts('#{name}') }
            assert true
          end
        end
      RUBY
    end
    out = succeeds('test')
    assert_match(/2 runs, 2 assertions/, out)
    assert_equal %w[first second], File.readlines(@env.fetch('TEST_TRACE'), chomp: true).sort
    write('test/failure_test.rb', "require 'minitest/autorun'\nclass FailureTest < Minitest::Test\ndef test_failure\nflunk\nend\nend\n")
    assert_match(/1 failures/, fails('test'))
    setting('TEST_COMMAND', "[#{RbConfig.ruby.inspect}, '-e', 'exit 9'].freeze")
    assert_match(/failed \(9\)/, fails('test'))
  end

  def test_standalone_scope_is_promoted_when_size_or_source_count_requires_it
    setting('PROFILE', ':script')
    succeeds('gate', '--full', env: { 'FAIL' => 'rubocop' })
    refute(trace.any? { |row| row.first == 'flay' })
    write('lib/another.rb', "# frozen_string_literal: true\n")
    assert_match(/failed/, fails('gate', env: { 'FAIL' => 'rubocop' }))
    FileUtils.rm(File.join(@repo, 'lib/another.rb'))
    File.open(File.join(@repo, 'bin/fixture'), 'a') { |file| file.write("# large\n" * 151) }
    assert_match(/failed/, fails('gate', env: { 'FAIL' => 'rubocop' }))
    assert_match(/Flay clone findings/, fails('gate', '--full', env: { 'FLAY_SCORE' => '80' }))
    assert_match(%r{Flay execution/report failure}, fails('gate', '--full', env: { 'FLAY_SKIP' => '1' }))
  end

  def test_syntax_warnings_and_invalid_versions_block_publication
    write('lib/bad.rb', "def broken(\n")
    assert_match(/syntax check failed/, fails('build'))
    FileUtils.rm(File.join(@repo, 'lib/bad.rb'))
    write('lib/version.rb', "VERSION = '1.2.3'\n")
    checkpoint
    add_remote
    assert_match(/exactly one VERSION/, fails('bump'))
    FileUtils.rm(File.join(@repo, 'lib/version.rb'))
    setting('VERSION_FILE', "'bin/fixture'")
    write('bin/fixture', "#!/usr/bin/env ruby\nVERSION = 'invalid'\n")
    checkpoint
    assert_match(/invalid semantic version/, fails('bump'))
    refute File.exist?(marker('release'))
  end

  def test_declared_links_and_text_version_releases
    target = File.join(@tmp, 'installed/fixture')
    setting('INSTALL_TARGETS', "{ 'bin/fixture' => #{target.inspect} }.freeze")
    succeeds('install', '--link')
    succeeds('install', '--link')
    assert_equal File.realpath(File.join(@repo, 'bin/fixture')), File.realpath(target)
    FileUtils.rm(target)
    File.symlink(RbConfig.ruby, target)
    assert_match(/unrelated symlink/, fails('install'))
    setting('VERSION_FILE', "'VERSION'")
    setting('VERSION_STYLE', ':text')
    write('VERSION', "1.2.3\n")
    checkpoint
    add_remote
    succeeds('bump', 'minor')
    assert_equal "1.3.0\n", File.read(File.join(@repo, 'VERSION'))
    assert_equal '1.2.3', current_version
  end

  def test_declared_output_must_be_valid_executable_ruby
    setting('ARTIFACTS', "['missing'].freeze")
    assert_match(/executable Ruby source/, fails('build'))
    write('bin/broken', "#!/usr/bin/env ruby\ndef broken(\n")
    File.chmod(0o755, File.join(@repo, 'bin/broken'))
    setting('ARTIFACTS', "['bin/broken'].freeze")
    assert_match(/syntax check failed/, fails('build'))
  end
end

class JuliaLanguageTest < ToolingFixture
  LANGUAGE = 'julia'

  def gh_rows
    trace.select { |row| row.first == 'gh' }
  end

  def publish_ready
    add_remote if git('remote').strip.empty?
    setting('GITHUB_REPO', "'owner/Fixture.jl'")
    checkpoint
    git('push', 'origin', 'main')
    reset_trace
  end

  # Registration is public and permanent, so publish refuses anything but a
  # clean, pushed package commit, and asks GitHub nothing before those checks.
  def test_publish_refuses_before_contacting_github
    assert_match(%r{\AUsage: tools/publish .*only when explicitly asked}m, succeeds('publish', '--help'))
    assert_empty trace, 'publish --help ran a tool'
    assert_match(/needs a branch with a pushed upstream/, fails('publish'))
    add_remote
    assert_match(/cannot tell the GitHub repository/, fails('publish'))
    publish_ready
    assert_match(/unknown option --bogus/, fails('publish', '--bogus'))
    write('change.txt', 'dirty')
    assert_match(/clean working tree/, fails('publish'))
    checkpoint
    assert_match(%r{is not the pushed refs/heads/main}, fails('publish'))
    git('push', 'origin', 'main')
    write('Project.toml', File.read(File.join(@repo, 'Project.toml')).sub(/^uuid.*\n/, ''))
    checkpoint
    git('push', 'origin', 'main')
    assert_match(/only a package can be registered/, fails('publish'))
    assert_empty gh_rows
  end

  def test_publish_dry_run_and_failed_ci_register_nothing
    publish_ready
    sha = git('rev-parse', 'HEAD').strip
    assert_match(%r{Register owner/Fixture.jl 1.2.3 at #{sha}}, succeeds('publish', '--dry-run'))
    assert_empty gh_rows
    fails('publish', env: { 'CI_FAIL' => '1', 'PUBLISH_POLL_SECONDS' => '0' })
    refute(gh_rows.any? { |row| row[1] == 'api' }, 'registered despite failed CI')
    assert_match(/no CI.yml run/, fails('publish', env: { 'GH_RUNS' => '[]', 'PUBLISH_POLL_SECONDS' => '0' }))
    refute(gh_rows.any? { |row| row[1] == 'api' })
  end

  def test_publish_comments_the_registration_on_the_pushed_commit
    publish_ready
    sha = git('rev-parse', 'HEAD').strip
    out = succeeds('publish', 'Breaking:', 'new', 'API', env: { 'PUBLISH_POLL_SECONDS' => '0' })
    assert_match(/Registration requested for 1.2.3/, out)
    watch = gh_rows.find { |row| row[1..2] == %w[run watch] }
    assert_equal ['--repo', 'owner/Fixture.jl', '--exit-status'], watch[4..6]
    api = gh_rows.find { |row| row[1] == 'api' }
    assert_equal "repos/owner/Fixture.jl/commits/#{sha}/comments", api[2]
    assert_equal "body=@JuliaRegistrator register\n\nRelease notes:\nBreaking: new API", api[4]
    refute(trace.any? { |row| row.first == 'git' && row[1] == 'push' }, 'publish pushed')
  end

  # TagBot tags a registered package after its registration merges, so the
  # default bump pushes the branch alone.
  def test_default_bump_pushes_no_tag_and_reads_only_the_top_level_version
    setting('RELEASE_TAG', 'false')
    write('Project.toml', File.read(File.join(@repo, 'Project.toml')) + "\n[extras]\nversion = \"9.9.9\"\n")
    checkpoint
    add_remote
    succeeds('bump')
    project = File.read(File.join(@repo, 'Project.toml'))
    assert_match(/^version = "1.2.4"$/, project)
    assert_match(/^version = "9.9.9"$/, project)
    assert_equal git('rev-parse', 'HEAD').strip, git('ls-remote', 'origin', 'refs/heads/main').split.first
    assert_empty git('ls-remote', '--tags', 'origin')
    assert(trace.any? { |row| row.first == 'julia' && row.last.include?('Pkg.test()') })
  end

  def test_missing_top_level_version_and_scripts_stop_the_tools
    write('Project.toml', File.read(File.join(@repo, 'Project.toml')).sub(/^version.*\n/, ''))
    checkpoint
    add_remote
    assert_match(/no top-level version/, fails('bump'))
    FileUtils.rm(File.join(@repo, 'bin/fixture'))
    assert_match(/build artifact missing/, fails('build'))
  end
end
