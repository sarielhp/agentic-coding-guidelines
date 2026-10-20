# frozen_string_literal: true

require_relative 'fixture'

class GatesTest < ToolFixture
  ISSUE = '{"code":"SA1000","severity":"error","location":{"file":"main.go","line":1,"column":1},"message":"example"}'

  def test_root_library_and_cmd_builds
    succeeds('build')
    assert File.executable?(File.join(@repo, 'bin/app'))
    setting('ARTIFACTS', '{}.freeze')
    reset_trace
    succeeds('build')
    assert_equal [['go', 'build', './...']], trace
    setting('ARTIFACTS', "{ 'fixture' => './cmd/fixture' }.freeze")
    succeeds('build')
    assert_equal 'built 1.2.3', File.read(File.join(@repo, 'fixture'))
    refute(trace.any? { |row| %w[test vet install].include?(row[1]) })
  end

  def test_output_escape_fails_before_build
    outside = File.join(@tmp, 'outside')
    FileUtils.mkdir_p(outside)
    File.symlink(outside, File.join(@repo, 'escape'))
    ['../escaped', '/tmp/escaped', 'escape/app'].each do |path|
      setting('ARTIFACTS', "{ #{path.inspect} => '.' }.freeze")
      reset_trace
      assert_match(/repository/, fails('build'))
      refute(trace.any? { |row| row[1] == 'build' })
    end
    assert_empty Dir.children(outside)
  end

  def test_missing_tool_and_crashed_analyzers_fail
    setting('TOOLS', "{ 'staticcheck' => '#{@tmp}/missing' }.freeze")
    err = fails('lint')
    assert_match(/required tool missing: staticcheck/, err)
  end

  def test_analyzer_failure_with_empty_or_unrecognized_output
    assert_match(/execution failed/, fails('lint', env: { 'FAIL_TOOL' => 'staticcheck' }))
    assert_match(/without findings/, fails('lint', env: { 'ANALYZER_STATUS' => '1' }))
    assert_match(/execution failed/, fails('lint', env: { 'FAIL_TOOL' => 'go-audit' }))
  end

  def test_baselines_preserve_counts_and_execution_status
    write('tools/staticcheck-baseline.txt', "#{ISSUE}\n")
    succeeds('lint', env: { 'FINDINGS' => ISSUE, 'ANALYZER_STATUS' => '1' })
    assert_match(/new findings/, fails('lint', env: { 'FINDINGS' => "#{ISSUE}\n#{ISSUE}", 'ANALYZER_STATUS' => '1' }))
    assert_match(/execution failed/, fails('lint', env: { 'FINDINGS' => ISSUE, 'ANALYZER_STATUS' => '2' }))
    audit = '[FAIL] 111 lines main.go:1 example() [length]'
    assert_match(/new findings/, fails('lint', env: { 'AUDIT_FINDINGS' => audit }))
    write('tools/go-audit-baseline.txt', "#{audit}\n")
    succeeds('lint', env: { 'AUDIT_FINDINGS' => audit })
    assert_match(/new findings/, fails('lint', env: { 'AUDIT_FINDINGS' => "#{audit}\n#{audit}" }))
  end

  def test_gate_check_equivalence_and_full_checks
    succeeds('gate')
    expected = trace
    reset_trace
    succeeds('check')
    assert_equal expected, trace
    assert_equal(1, trace.count { |row| row == ['go', 'vet', './...'] })
    assert_equal(1, trace.count { |row| row == ['go', 'build', './...'] })
    reset_trace
    succeeds('check', '--full')
    assert(trace.any? { |row| row.include?('-race') })
    %w[govulncheck gocritic shadow revive dupl].each do |name|
      assert(trace.any? { |row| row.first == name || row.include?("-vettool=#{@bin}/#{name}") })
    end
    assert_match(/failed/, fails('gate', '--full', env: { 'FAIL_TOOL' => 'govulncheck' }))
  end

  def test_real_go_root_library_cmd_and_fast_gate
    real = { 'USE_REAL_GO' => '1' }
    write('main_test.go', "package main\n\nimport \"testing\"\n\nfunc TestRunMain(t *testing.T) {\n\tt.Helper()\n\tmain()\n}\n")
    succeeds('build', env: real)
    assert File.executable?(File.join(@repo, 'bin/app'))
    succeeds('gate', env: real)
    write('main_test.go', "package main\n\nimport \"testing\"\n\nfunc TestRunMain(t *testing.T) { t.Fatal(\"fixture failure\") }\n")
    reset_trace
    assert_match(/fixture failure/, fails('gate', env: real))
    refute(trace.any? { |row| row[1] == 'build' })
    FileUtils.rm(File.join(@repo, 'main_test.go'))
    write('main.go', "package fixture\n\nfunc Answer() int { return 42 }\n")
    succeeds('build', env: real)
    succeeds('check', env: real)
    write('cmd/fixture/main.go', "package main\n\nfunc main() {}\n")
    setting('ARTIFACTS', "{ 'fixture' => './cmd/fixture' }.freeze")
    succeeds('build', env: real)
    assert File.executable?(File.join(@repo, 'fixture'))
    succeeds('check', '--full', env: real)
    FileUtils.rm(File.join(@repo, 'main.go'))
    FileUtils.rm_rf(File.join(@repo, 'cmd'))
    write('pkg/fixture/fixture.go', "package fixture\n\nfunc Answer() int { return 42 }\n")
    setting('ARTIFACTS', 'nil')
    succeeds('build', env: real)
    succeeds('check', env: real)
  end

  def test_real_staticcheck_and_cognitive_audit
    staticcheck = [File.expand_path('~/.go/bin/staticcheck'), File.expand_path('~/go/bin/staticcheck')]
                  .find { |path| File.file?(path) && File.executable?(path) }
    skip 'optional real staticcheck not available' unless staticcheck

    setting('TOOLS', "{ 'staticcheck' => #{staticcheck.inspect}, " \
                     "'go-audit' => #{File.expand_path('../bin/go-audit', __dir__).inspect} }.freeze")
    succeeds('lint', env: { 'USE_REAL_GO' => '1' })
    write('main.go', "package main\n\nfunc main() {}\n\nfunc unused() {}\n")
    assert_match(/new findings/, fails('lint', env: { 'USE_REAL_GO' => '1' }))
  end

  def test_gate_runs_go_with_the_automatic_toolchain
    path = File.join(@tmp, 'toolchain')
    succeeds('gate', env: { 'GOTOOLCHAIN' => 'local', 'TOOLCHAIN_TRACE' => path })
    assert_equal 'auto', File.read(path)
  end

  def test_full_gate_rejects_analyzers_built_with_another_go
    succeeds('gate', '--full', env: { 'ANALYZER_GO' => 'go1.26.0' })
    reset_trace
    err = fails('gate', '--full', env: { 'ANALYZER_GO' => 'go1.25.9' })
    assert_match(/analyzers built with another Go than go1.26.0: staticcheck \(go1.25.9\).*go-install-tools/, err)
    refute(trace.any? { |row| row.first == 'govulncheck' })
  end

  def test_make_delegates_once
    write('Makefile', File.read(File.join(TEMPLATES, 'Makefile.snippet')))
    %w[gate check lint ci].each do |target|
      reset_trace
      out, err, status = Open3.capture3(@env, 'make', target, chdir: @repo)
      assert status.success?, "#{out}#{err}"
      assert_equal(1, trace.count { |row| row == ['go', 'vet', './...'] })
      assert_equal(target == 'ci', trace.any? { |row| row.include?('-race') })
    end
  end
end
