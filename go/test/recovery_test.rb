# frozen_string_literal: true

require_relative 'fixture'

class RecoveryTest < ToolFixture
  def test_failed_staging_commit_and_gate_resume_without_rebump
    add_remote
    fails('bump', env: { 'FAIL_GIT' => 'add' })
    assert_equal "1.2.4\n", File.read(File.join(@repo, 'VERSION'))
    assert_match(/git commit failed/, fails('bump', '--resume', env: { 'FAIL_GIT' => 'commit' }))
    succeeds('bump', '--resume')
    assert_equal "1.2.4\n", File.read(File.join(@repo, 'VERSION'))
    fails('bump', env: { 'FAIL_TOOL' => 'govulncheck' })
    succeeds('bump', '--resume')
    assert_equal "1.2.5\n", File.read(File.join(@repo, 'VERSION'))
  end

  def test_ignored_required_inputs_invalidate_full_verification
    setting('VERSION_KIND', ':metadata')
    setting('VERIFICATION_INPUTS', "['private-check-input'].freeze")
    write('.gitignore', "/bin/\n/private-check-input\n")
    write('private-check-input', 'before')
    add_remote
    succeeds('commit', '--full', 'chore: settings')
    write('private-check-input', 'after')
    reset_trace
    succeeds('bump')
    assert(trace.any? { |row| row.include?('-race') })
  end

  def test_changed_ignored_settings_and_tool_identity_invalidate_verification
    setting('VERSION_KIND', ':metadata')
    write('.gitignore', "/bin/\n/tools/settings.rb\n")
    command('rm', '--cached', 'tools/settings.rb')
    add_remote
    succeeds('commit', '--full', 'chore: ignored settings')
    setting('TEST_TIMEOUT', "'179s'")
    reset_trace
    succeeds('bump')
    assert(trace.any? { |row| row.include?('-race') })
    write('change.txt', 'next')
    succeeds('commit', '--full', 'fix: next')
    File.open(File.join(@bin, 'staticcheck'), 'a') { |file| file.puts('# tool identity changed') }
    reset_trace
    succeeds('bump')
    assert(trace.any? { |row| row.include?('-race') })
  end

  def test_corrupted_installation_is_detected
    target = File.join(@tmp, 'installed/app')
    setting('INSTALL_TARGETS', "{ 'bin/app' => #{target.inspect} }.freeze")
    # Inject corruption immediately after the copy in this disposable tool copy.
    path = File.join(@repo, 'tools/tooling.rb')
    contents = File.read(path)
    contents.sub!('FileUtils.cp(built, destination, preserve: true)',
                  "FileUtils.cp(built, destination, preserve: true)\n      File.binwrite(destination, 'corrupt')")
    File.write(path, contents)
    assert_match(/installed artifact mismatch/, fails('install'))
  end

  def test_release_optional_install_runs_after_verified_push
    target = File.join(@tmp, 'installed/app')
    setting('INSTALL_TARGETS', "{ 'bin/app' => #{target.inspect} }.freeze")
    add_remote
    write('change.txt', 'hello')
    succeeds('release', '--install', 'fix: installed release')
    assert_equal 'built 1.2.4', File.read(target)
    assert_equal(1, trace.count { |row| row.include?('-race') })
    pushed = trace.index { |row| row.first == 'git' && row[1] == 'ls-remote' }
    final_build = trace.rindex { |row| row.first == 'go' && row[1] == 'build' }
    assert_operator final_build, :>, pushed
  end

  def test_deleted_sources_can_be_committed
    write('obsolete.txt', 'old')
    checkpoint
    FileUtils.rm(File.join(@repo, 'obsolete.txt'))
    succeeds('commit', 'chore: remove obsolete file')
    assert File.file?(record_path)
  end

  def test_distinct_push_url_is_used_for_verification
    add_remote
    destination = File.join(@tmp, 'push-destination.git')
    command('init', '--bare', destination)
    command('remote', 'set-url', '--push', 'origin', destination)
    succeeds('bump')
    pushed = command('ls-remote', destination, 'refs/heads/main').split.first
    assert_equal command('rev-parse', 'HEAD').strip, pushed
    refute_equal pushed, command('ls-remote', 'origin', 'refs/heads/main').split.first
  end

  def test_commit_hooks_cannot_record_unchecked_source
    write('change.txt', 'hello')
    hook = File.join(@repo, '.git/hooks/pre-commit')
    File.write(hook, "#!#{RbConfig.ruby}\nFile.write('main.go', \"package main\\n\\nfunc main() { println(1) }\\n\")\n")
    File.chmod(0o755, hook)
    assert_match(/commit hook changed/, fails('commit', '--full', 'fix: hook'))
    refute File.exist?(record_path)
  end
end
