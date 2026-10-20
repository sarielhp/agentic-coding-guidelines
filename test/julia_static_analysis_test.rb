# frozen_string_literal: true

require 'minitest/autorun'
require 'open3'
require 'tmpdir'
require 'fileutils'

# Acceptance tests for julia/bin/julia-static-analysis and julia-install-tools.
# They need Julia >= 1.10 and a tools environment holding JuliaFormatter, JET,
# ExplicitImports, and Aqua: point JULIA_STANDARDS_ENV at one. They skip themselves
# otherwise; nothing here installs packages.
class JuliaStaticAnalysisTest < Minitest::Test
  ROOT = File.expand_path('..', __dir__)
  ANALYSIS = File.join(ROOT, 'julia', 'bin', 'julia-static-analysis')
  INSTALLER = File.join(ROOT, 'julia', 'bin', 'julia-install-tools')
  LINEAR_ALGEBRA = '37e2e46d-f89d-539d-b4ee-838fcccc9c8e'

  def setup
    @tools = ENV.fetch('JULIA_STANDARDS_ENV', nil)
    skip 'set JULIA_STANDARDS_ENV to a tools environment' unless @tools && File.file?(File.join(@tools, 'Project.toml'))
    skip 'julia is not on PATH' unless system('julia', '--version', out: File::NULL, err: File::NULL)
    @tmp = Dir.mktmpdir('julia-static-test')
    FileUtils.mkdir_p(File.join(@tmp, 'src'))
    write('Project.toml', <<~TOML)
      name = "Fixture"
      uuid = "00000000-0000-0000-0000-000000000002"

      [deps]
      LinearAlgebra = "#{LINEAR_ALGEBRA}"
    TOML
    write('.JuliaFormatter.toml', "style = \"default\"\n")
  end

  def teardown
    FileUtils.remove_entry(@tmp) if @tmp
  end

  def write(relative, text)
    path = File.join(@tmp, relative)
    File.write(path, text)
    path
  end

  def package(body)
    write('src/Fixture.jl', "module Fixture\n\n#{body}\nend\n")
  end

  def analyze(*, env: {})
    Open3.capture3({ 'JULIA_STANDARDS_ENV' => @tools }.merge(env), [ANALYSIS, ANALYSIS], *, chdir: @tmp)
  end

  def test_syntax_errors_fail
    path = write('bad.jl', "function f(\n")
    _, err, status = analyze('--syntax', path)
    refute status.success?
    assert_match(/syntax error|check failed/, err + File.read(path))
  end

  def test_formatting_is_checked_without_modifying_files
    path = write('loose.jl', "f( x )   =   x+1\n")
    _, err, status = analyze('--format', path)
    refute status.success?
    assert_match(/not formatted/, err)
    assert_equal "f( x )   =   x+1\n", File.read(path)
    write('tidy.jl', "f(x) = x + 1\n")
    _, err, status = analyze('--format', File.join(@tmp, 'tidy.jl'))
    assert status.success?, err
  end

  def test_default_checks_for_a_single_file_are_syntax_and_formatting
    path = write('tidy.jl', "f(x) = x + 1\n")
    out, err, status = analyze(path)
    assert status.success?, err
    assert_match(/Syntax passed/, out)
    assert_match(/Format passed/, out)
    refute_match(/JET/, out)
  end

  def test_jet_reports_method_errors_and_passes_clean_packages
    package("f(x::Int) = x + \"a\"\n")
    out, err, status = analyze('--jet', 'src')
    refute status.success?
    assert_match(/JET found/, err)
    assert_match(/Fixture.jl:3/, out)
    package("f(x::Int) = x + 1\n")
    out, err, status = analyze('--jet', 'src')
    assert status.success?, err
    assert_match(/JET passed/, out)
  end

  def test_stale_explicit_imports_fail_and_clean_imports_pass
    package("using LinearAlgebra: norm\n\nf(x) = x\n")
    _, err, status = analyze('--imports', 'src')
    refute status.success?
    assert_match(/check_no_stale_explicit_imports/, err)
    package("using LinearAlgebra: norm\n\nf(x) = norm(x)\n")
    out, err, status = analyze('--imports', 'src')
    assert status.success?, err
    assert_match(/Imports passed/, out)
  end

  def test_projects_get_jet_and_import_checks_by_default
    package("f(x::Int) = x + \"a\"\n")
    _, err, status = analyze('src')
    refute status.success?
    assert_match(/JET found/, err)
  end

  def test_project_checks_need_a_project
    path = write('tidy.jl', "f(x) = x + 1\n")
    FileUtils.rm_f(File.join(@tmp, 'Project.toml'))
    _, err, status = analyze('--jet', path)
    refute status.success?
    assert_match(/need a project/, err)
  end

  def test_missing_tools_environment_is_a_failure_and_is_not_installed
    empty = File.join(@tmp, 'no-tools')
    path = write('tidy.jl', "f(x) = x + 1\n")
    _, err, status = analyze('--format', path, env: { 'JULIA_STANDARDS_ENV' => empty })
    refute status.success?
    assert_match(/tools environment missing/, err)
    refute File.exist?(empty)
  end

  def test_installer_check_only_reports_and_never_installs
    out, err, status = Open3.capture3({ 'JULIA_STANDARDS_ENV' => @tools }, INSTALLER, '--check-only')
    assert status.success?, err
    assert_match(/JuliaFormatter/, out)
    empty = File.join(@tmp, 'empty-env')
    out, _, status = Open3.capture3({ 'JULIA_STANDARDS_ENV' => empty }, INSTALLER, '--check-only')
    refute status.success?
    assert_match(/MISSING/, out.gsub(/\e\[[0-9;]*m/, ''))
    refute File.exist?(empty)
  end
end
