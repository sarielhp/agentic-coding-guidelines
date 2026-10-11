# frozen_string_literal: true

require_relative 'fixture'

class LifecycleTest < ToolFixture
  def test_literal_commit_messages_and_local_snapshot
    message = 'fix: "quotes" $(touch injected) `touch injected` ; $HOME'
    write('change.txt', 'hello')
    succeeds('commit', message)
    assert_equal message, command('log', '-1', '--format=%s').strip
    refute File.exist?(File.join(@repo, 'injected'))
    assert_equal 'fast', JSON.parse(File.read(record_path)).fetch('level')
    write('change.txt', 'snapshot')
    reset_trace
    succeeds('snapshot')
    refute(trace.any? { |row| row.first == 'go' || row[1] == 'push' })
  end

  def test_absent_gate_nonzero_gate_staging_and_commit_failures
    write('change.txt', 'hello')
    FileUtils.rm(File.join(@repo, 'tools/gate'))
    assert_match(/required entry point missing/, fails('commit', 'fix: test'))
    refute File.exist?(record_path)
    copy_templates
    assert_match(/failed/, fails('commit', 'fix: test', env: { 'FAIL_TOOL' => 'go' }))
    %w[add commit].each do |operation|
      assert_match(/git #{operation} failed/, fails('commit', 'fix: test', env: { 'FAIL_GIT' => operation }))
      refute File.exist?(record_path)
    end
  end

  def test_missing_upstream_invalid_version_and_dirty_state_are_preflight_failures
    assert_match(/failed/, fails('bump'))
    assert_equal "1.2.3\n", File.read(File.join(@repo, 'VERSION'))
    add_remote
    write('VERSION', "1.2\n")
    assert_match(/invalid semantic version/, fails('bump'))
    write('VERSION', "1.2.3\n")
    write('change.txt', 'dirty')
    assert_match(/clean working tree/, fails('bump'))
    assert_equal "1.2.3\n", File.read(File.join(@repo, 'VERSION'))
  end

  def test_fast_and_legacy_verification_cannot_skip_full_release
    add_remote
    write('change.txt', 'hello')
    succeeds('commit', 'fix: change')
    reset_trace
    succeeds('bump')
    assert(trace.any? { |row| row.include?('-race') })
    File.write(record_path, command('rev-parse', 'HEAD'))
    reset_trace
    succeeds('bump')
    assert(trace.any? { |row| row.include?('-race') })
    assert_equal "1.2.5\n", File.read(File.join(@repo, 'VERSION'))
  end

  def test_metadata_full_verification_reuses_checks_and_rebuilds
    setting('VERSION_KIND', ':metadata')
    add_remote
    succeeds('commit', '--full', 'chore: metadata')
    reset_trace
    succeeds('bump')
    refute(trace.any? { |row| row.include?('-race') || row[1] == 'test' })
    assert(trace.any? { |row| row[1] == 'build' })
    assert_equal 'built 1.2.4', File.read(File.join(@repo, 'bin/app'))
    assert_equal command('rev-parse', 'HEAD').strip, command('ls-remote', 'origin', 'refs/heads/main').split.first
    refute File.exist?(record_path)
  end

  def test_changed_source_settings_baselines_and_embed_invalidate_reuse
    setting('VERSION_KIND', ':metadata')
    add_remote
    succeeds('commit', '--full', 'chore: settings')
    write('main.go', "package main\n\nfunc main() { println(1) }\n")
    checkpoint
    reset_trace
    succeeds('bump')
    assert(trace.any? { |row| row.include?('-race') })
    write('tools/staticcheck-baseline.txt', '')
    succeeds('commit', '--full', 'chore: baseline')
    reset_trace
    succeeds('bump', env: { 'EMBED_FILES' => 'VERSION' })
    assert(trace.any? { |row| row.include?('-race') })
  end

  def test_rejected_push_resumes_without_another_bump
    bare = add_remote
    hook = File.join(bare, 'hooks/pre-receive')
    File.write(hook, "#!#{RbConfig.ruby}\nexit 1\n")
    File.chmod(0o755, hook)
    err = fails('bump')
    assert_match(/Local state retained/, err)
    assert_equal "1.2.4\n", File.read(File.join(@repo, 'VERSION'))
    assert_match(/unfinished release/, fails('bump'))
    FileUtils.rm(hook)
    succeeds('bump', '--resume')
    assert_equal "1.2.4\n", File.read(File.join(@repo, 'VERSION'))
    refute File.exist?(record_path('release'))
  end

  def test_remote_mismatch_and_query_failures_preserve_resume_state
    add_remote
    assert_match(/remote verification mismatch/, fails('bump', env: { 'REMOTE_MISMATCH' => '1' }))
    assert File.exist?(record_path('release'))
    assert_match(/ls-remote failed/, fails('bump', '--resume', env: { 'FAIL_GIT' => 'ls-remote' }))
    succeeds('bump', '--resume')
    assert_equal "1.2.4\n", File.read(File.join(@repo, 'VERSION'))
  end

  def test_install_declared_targets_and_failure
    assert_match(/unsupported/, fails('install'))
    target = File.join(@tmp, 'installed/app')
    setting('INSTALL_TARGETS', "{ 'bin/app' => #{target.inspect} }.freeze")
    succeeds('install')
    assert_equal File.binread(File.join(@repo, 'bin/app')), File.binread(target)
    assert File.executable?(target)
    reset_trace
    refute(trace.any? { |row| row.first == 'git' })
    setting('INSTALL_TARGETS', "{ 'bin/app' => #{@tmp.inspect} }.freeze")
    assert_match(/mismatch|directory/, fails('install'))
  end

  def test_release_orders_full_gate_push_and_optional_install
    add_remote
    write('change.txt', 'hello')
    succeeds('release', 'fix: release')
    assert_equal(1, trace.count { |row| row.include?('-race') })
    refute(trace.any? { |row| row[1] == 'install' })
    reset_trace
    write('change.txt', 'next')
    err = fails('release', '--install', 'fix: next')
    assert_match(/installation unsupported/, err)
    assert_match(/Release published and verified; installation failed/, err)
    assert_equal command('rev-parse', 'HEAD').strip, command('ls-remote', 'origin', 'refs/heads/main').split.first
  end

  def test_release_stops_on_commit_and_bump_failure
    add_remote
    write('change.txt', 'hello')
    fails('release', '--install', 'fix: failure', env: { 'FAIL_GIT' => 'commit' })
    refute(trace.any? { |row| row[1] == 'push' })
    assert_equal "1.2.3\n", File.read(File.join(@repo, 'VERSION'))
    reset_trace
    fails('release', '--install', 'fix: failure', env: { 'FAIL_TOOL' => 'govulncheck' })
    refute(trace.any? { |row| row[1] == 'push' })
  end
end
