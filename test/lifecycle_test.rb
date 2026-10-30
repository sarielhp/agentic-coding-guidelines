# frozen_string_literal: true

require_relative 'tooling_fixture'

module LifecycleContract
  def test_commit_is_local_and_message_is_literal
    write('change.txt', 'hello')
    message = 'fix: "quotes" $(touch injected) `touch injected` ; $HOME'
    succeeds('commit', message)
    assert_equal message, git('log', '-1', '--format=%s').strip
    refute File.exist?(File.join(@repo, 'injected'))
    refute(trace.any? { |row| row[1] == 'push' })
    assert_equal 'fast', JSON.parse(File.read(marker)).fetch('level')
  end

  def test_missing_gate_and_failed_analyzers_stop_commit
    write('change.txt', 'hello')
    FileUtils.rm(File.join(@repo, 'tools/gate'))
    assert_match(/required entry point missing/, fails('commit', 'fix: test'))
    refute File.exist?(marker)
    copy_templates
    analyzer = auditor
    assert_match(/failed/, fails('commit', 'fix: test', env: { 'FAIL' => analyzer }))
    refute File.exist?(marker)
    setting('TOOLS', "{ #{analyzer.inspect} => '#{@tmp}/missing' }.freeze")
    assert_match(/required tool missing/, fails('gate'))
  end

  def test_staging_commit_and_tag_failures_are_checked
    write('change.txt', 'hello')
    %w[add commit].each do |operation|
      assert_match(/git #{operation} failed/, fails('commit', 'fix: test', env: { 'FAIL' => "git:#{operation}" }))
      refute File.exist?(marker)
    end
    succeeds('commit', 'fix: test')
    add_remote
    assert_match(/git tag failed/, fails('bump', env: { 'FAIL' => 'git:tag' }))
    assert_equal '1.2.4', current_version
    assert File.file?(marker('release'))
    succeeds('bump', '--resume')
    assert_equal '1.2.4', current_version
  end

  def test_upstream_invalid_version_and_dirty_state_fail_before_version_changes
    fails('bump')
    assert_equal '1.2.3', current_version
    add_remote
    write('change.txt', 'dirty')
    assert_match(/clean working tree/, fails('bump'))
    assert_equal '1.2.3', current_version
  end

  def test_full_release_checks_changed_version_and_verifies_only_release_tag
    add_remote
    git('tag', '-a', 'unrelated', '-m', 'not part of release')
    File.write(marker, git('rev-parse', 'HEAD'))
    succeeds('bump')
    assert_equal '1.2.4', current_version
    sha = git('rev-parse', 'HEAD').strip
    assert_equal sha, git('ls-remote', 'origin', 'refs/heads/main').split.first
    assert_equal sha, git('ls-remote', 'origin', 'refs/tags/v1.2.4^{}').split.first
    assert_empty git('ls-remote', 'origin', 'refs/tags/unrelated')
    assert(trace.any? { |row| deep_review_row?(row) })
    refute File.exist?(marker('release'))
  end

  def test_push_rejection_and_remote_mismatch_resume_without_another_bump
    bare = add_remote
    hook = File.join(bare, 'hooks/pre-receive')
    File.write(hook, "#!#{RbConfig.ruby}\nexit 1\n")
    File.chmod(0o755, hook)
    assert_match(/Local state retained/, fails('bump'))
    assert_match(/unfinished release/, fails('bump'))
    assert_equal '1.2.4', current_version
    FileUtils.rm(hook)
    assert_match(/remote branch mismatch/, fails('bump', '--resume', env: { 'REMOTE_MISMATCH' => '1' }))
    succeeds('bump', '--resume')
    assert_equal '1.2.4', current_version
  end

  def test_failed_staging_resume_preserves_pending_version
    add_remote
    assert_match(/git add failed/, fails('bump', env: { 'FAIL' => 'git:add' }))
    assert_equal '1.2.4', current_version
    succeeds('bump', '--resume')
    assert_equal '1.2.4', current_version
  end

  def test_commit_hook_mutation_cannot_record_verification
    write('change.txt', 'hello')
    hook = File.join(@repo, '.git/hooks/pre-commit')
    File.write(hook, "#!#{RbConfig.ruby}\nFile.write('change.txt', 'unchecked')\n")
    File.chmod(0o755, hook)
    assert_match(/commit hook changed/, fails('commit', '--full', 'fix: hook'))
    refute File.exist?(marker)
  end

  def test_install_requires_build_and_declared_targets_and_verifies_contents
    assert_match(/unsupported/, fails('install'))
    target = File.join(@tmp, 'installed/fixture')
    setting('INSTALL_TARGETS', "{ #{artifact.inspect} => #{target.inspect} }.freeze")
    succeeds('install')
    assert_equal File.binread(File.join(@repo, artifact)), File.binread(target)
    assert File.executable?(target)
    assert_match(/undeclared installation names/, fails('install', 'unknown'))
    FileUtils.rm(File.join(@repo, 'tools/build'))
    assert_match(/required entry point missing/, fails('install'))
  end

  def test_install_detects_corruption
    target = File.join(@tmp, 'installed/fixture')
    setting('INSTALL_TARGETS', "{ #{artifact.inspect} => #{target.inspect} }.freeze")
    path = File.join(@repo, 'tools/tooling.rb')
    content = File.read(path)
    content.sub!('FileUtils.cp(built, destination, preserve: true) unless link',
                 "FileUtils.cp(built, destination, preserve: true) unless link\n    File.binwrite(destination, 'corrupt')")
    File.write(path, content)
    assert_match(/installed artifact mismatch/, fails('install'))
  end

  def test_release_stops_after_each_failed_stage_and_install_is_opt_in
    add_remote
    write('change.txt', 'hello')
    fails('release', '--install', 'fix: failure', env: { 'FAIL' => 'git:commit' })
    refute(trace.any? { |row| row[1] == 'push' })
    assert_equal '1.2.3', current_version
    reset_trace
    succeeds('release', 'fix: release')
    assert_equal '1.2.4', current_version
    write('change.txt', 'next')
    assert_match(/published and verified; installation failed/, fails('release', '--install', 'fix: next'))
    assert_equal '1.2.5', current_version
  end

  def test_snapshot_has_no_gate_or_push
    write('change.txt', 'checkpoint')
    succeeds('snapshot', 'chore: checkpoint')
    refute(trace.any? { |row| row.first != 'git' || row[1] == 'push' })
  end

  def test_gate_check_and_make_delegates_do_not_duplicate_work
    succeeds('gate')
    expected = trace.count { |row| row.first == auditor }
    reset_trace
    succeeds('check')
    assert_equal(expected, trace.count { |row| row.first == auditor })
    write('Makefile', File.read(File.join(ToolingFixture::ROOT, self.class::LANGUAGE, 'templates/Makefile.snippet')))
    reset_trace
    out, err, status = Open3.capture3(@env, 'make', 'check', chdir: @repo)
    assert status.success?, "#{out}#{err}"
    assert_equal(1, trace.count { |row| row.first == auditor })
  end

  def test_ignored_inputs_invalidate_resume_verification
    setting('VERIFICATION_INPUTS', "['private-input'].freeze")
    write('.gitignore', "/target/\n/private-input\n")
    write('private-input', 'before')
    checkpoint
    add_remote
    fails('bump', env: { 'FAIL' => 'git:push' })
    write('private-input', 'after')
    assert_match(/checked inputs changed/, fails('bump', '--resume'))
  end

  # `tools/release --help` once committed pending work as "--help", bumped the
  # version and pushed. Help must print and run nothing, wherever the flag sits;
  # a message that looks like an option must be refused before anything runs.
  def test_help_runs_nothing_and_option_like_messages_are_refused
    write('change.txt', 'pending')
    state = [git('rev-parse', 'HEAD'), git('status', '--porcelain')]
    reset_trace
    %w[release commit snapshot bump gate install lint test build check].each do |name|
      %w[--help -h].each { |flag| assert_match(%r{\AUsage: tools/}, succeeds(name, flag)) }
    end
    assert_match(%r{\AUsage: tools/release}, succeeds('release', '--install', 'fix: real', '-h'))
    assert_match(%r{\AUsage: tools/install}, succeeds('install', '--link', '--help'))
    assert_empty trace, 'help ran a tool'
    %w[release commit snapshot].each do |name|
      assert_match(/looks like an option: --bogus/, fails(name, '--bogus'))
    end
    assert_match(/commit message is empty/, fails('commit', '  '))
    refute(trace.any? { |row| %w[add commit push].include?(row[1]) }, 'a refused message reached git')
    assert_equal state, [git('rev-parse', 'HEAD'), git('status', '--porcelain')]
  end
end

class RustLifecycleTest < ToolingFixture
  LANGUAGE = 'rust'
  include LifecycleContract
end

class RubyLifecycleTest < ToolingFixture
  LANGUAGE = 'ruby'
  include LifecycleContract
end

class JuliaLifecycleTest < ToolingFixture
  LANGUAGE = 'julia'
  include LifecycleContract
end
