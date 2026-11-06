# frozen_string_literal: true

require_relative 'tmp_env'
require 'fileutils'
require 'minitest/autorun'
require 'open3'
require 'rbconfig'
require 'tmpdir'

class LatexToolsTest < Minitest::Test
  ROOT = File.expand_path('..', __dir__)
  LATEX_ROOT = File.join(ROOT, 'latex')
  TOOLS = File.join(LATEX_ROOT, 'tools')
  TEMPLATES = File.join(LATEX_ROOT, 'templates')

  def run_tool(name, *)
    tool_path = File.join(TOOLS, name)
    Open3.capture3(RbConfig.ruby, tool_path, *)
  end

  def test_latex_indent_version_and_help
    out, _err, status = run_tool('latex_indent', '--version')
    assert status.success?
    assert_match(/latex_indent \d+\.\d+\.\d+/, out)

    out, _err, status = run_tool('latex_indent', '--help')
    assert status.success?
    assert_includes out, 'PART OF THE LATEX STANDARD'
  end

  def test_latex_fix_layout_version_and_help
    out, _err, status = run_tool('latex_fix_layout', '--version')
    assert status.success?
    assert_match(/latex_fix_layout \d+\.\d+\.\d+/, out)

    out, _err, status = run_tool('latex_fix_layout', '--help')
    assert status.success?
    assert_includes out, 'PART OF THE LATEX STANDARD'
  end

  def test_latex_check_conventions_version_and_help
    out, _err, status = run_tool('latex_check_conventions', '--version')
    assert status.success?
    assert_match(/latex_check_conventions \d+\.\d+\.\d+/, out)

    out, _err, status = run_tool('latex_check_conventions', '--help')
    assert status.success?
    assert_includes out, 'PART OF THE LATEX STANDARD'
  end

  def test_templates_pass_checks
    example_tex = File.join(TEMPLATES, 'example.tex')
    out, err, status = run_tool('latex_check_conventions', example_tex)
    assert status.success?, "#{out}#{err}"
    assert_includes out, 'No convention violations found.'

    out, err, status = run_tool('latex_indent', '--check', example_tex)
    assert status.success?, "#{out}#{err}"
  end

  def test_convention_checker_detects_violations
    Dir.mktmpdir('check-') do |dir|
      bad_tex = File.join(dir, 'bad.tex')
      File.write(bad_tex, "\\bibliographystyle{plain}\n\\label{raw}\n$$x=1$$\n")
      out, _err, status = run_tool('latex_check_conventions', bad_tex)
      refute status.success?
      assert_includes out, 'direct label/ref command'
      assert_includes out, 'BibTeX command'
      assert_includes out, 'use \\[...\\] instead of $$...$$'
    end
  end
end
