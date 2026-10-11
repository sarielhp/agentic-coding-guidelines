# frozen_string_literal: true

require_relative 'tooling_fixture'

module AnalyzerContract
  def analyze(*, env: {})
    path = File.join(ToolingFixture::ROOT, self.class::LANGUAGE, 'bin', "#{self.class::LANGUAGE}-static-analysis")
    Open3.capture3(@env.merge(env), [path, path], *, chdir: @repo)
  end

  def test_explicit_check_runs_only_selected_analyzer_and_checks_failure
    flag = self.class::LANGUAGE == 'rust' ? '--audit' : '--rubocop'
    tool = self.class::LANGUAGE == 'rust' ? 'cargo-audit' : 'rubocop'
    _, err, status = analyze(flag, env: { 'FAIL' => tool })
    refute status.success?
    assert_match(/failed/, err)
    assert_equal [tool], trace.map(&:first)
  end

  def test_default_missing_analyzer_is_a_failure
    tool = self.class::LANGUAGE == 'rust' ? 'cargo' : 'rubocop'
    File.write(File.join(@bin, tool), "#!#{RbConfig.ruby}\nabort 'required analyzer unavailable'\n")
    _, err, status = analyze
    refute status.success?
    assert_match(/failed/, err)
  end
end

class RustAnalyzerTest < ToolingFixture
  LANGUAGE = 'rust'
  include AnalyzerContract

  def test_duplicate_provider_is_required_and_exit_status_is_checked
    _, err, status = analyze('--dups')
    refute status.success?
    assert_match(/explicit executable/, err)
    write('tools/check_duplicates', "#!#{RbConfig.ruby}\nexit 12\n")
    File.chmod(0o755, File.join(@repo, 'tools/check_duplicates'))
    _, err, status = analyze('--dups')
    refute status.success?
    assert_match(/failed \(12\)/, err)
  end

  def test_external_target_directory_is_rejected_before_analysis
    _, err, status = analyze('--clippy', env: { 'CARGO_TARGET_DIR' => @tmp })
    refute status.success?
    assert_match(/inside the analyzed repository/, err)
    assert_empty trace
  end
end

class RubyAnalyzerTest < ToolingFixture
  LANGUAGE = 'ruby'
  include AnalyzerContract

  def test_flay_findings_parser_skips_and_missing_lock_are_failures
    [{ 'FLAY_SCORE' => '90' }, { 'FLAY_SKIP' => '1' }, { 'FAIL' => 'flay' }].each do |env|
      _, _, status = analyze('--dups', env: env)
      refute status.success?
    end
    _, err, status = analyze('--vuln')
    refute status.success?
    assert_match(/requires Gemfile.lock/, err)
  end

  def test_extensionless_syntax_and_upward_configuration
    _, _, status = analyze('--syntax', 'bin/fixture')
    assert status.success?
    _, _, status = analyze('--rubocop', 'bin/fixture')
    assert status.success?
    assert_equal File.join(@repo, '.rubocop.yml'), trace.last[2]
    write('bin/broken', "#!/usr/bin/env ruby\ndef broken(\n")
    _, err, status = analyze('--syntax', 'bin/broken')
    refute status.success?
    assert_match(/syntax check failed/, err)
  end

  def test_bootstrap_check_only_does_not_create_directories_or_report_success_when_incomplete
    bootstrap = File.join(ROOT, 'ruby/bin/ruby-install-tools')
    script = <<~RUBY
      load #{bootstrap.inspect}
      RubyDevInstaller.instance_variable_set(:@user_gem_bindir, #{File.join(@tmp, 'absent-gem-bin').inspect})
      def RubyDevInstaller.gem_available?(_name)
        false
      end
      exit RubyDevInstaller.run(['--check-only'])
    RUBY
    out, _, status = Open3.capture3(@env, RbConfig.ruby, '-e', script, chdir: @repo)
    refute status.success?
    assert_match(/flay/, out)
    refute File.exist?(File.join(@tmp, 'absent-gem-bin'))
  end
end
