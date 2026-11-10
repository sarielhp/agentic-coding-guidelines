# frozen_string_literal: true

require_relative 'tmp_env'
require 'fileutils'
require 'minitest/autorun'
require 'open3'
require 'rbconfig'
require 'tmpdir'

# Acceptance tests for latex/tools/git_latex_setup and git_latex_sync, run against
# disposable repositories and a local bare remote standing in for Overleaf.
class LatexGitToolsTest < Minitest::Test
  TOOLS = File.expand_path('../latex/tools', __dir__)
  HELP_FLAGS = %w[-h -H --help -help --H --h].freeze
  # Isolates git from the user's configuration and gives it an identity.
  GIT_ENV = {
    'GIT_CONFIG_GLOBAL' => File::NULL, 'GIT_CONFIG_NOSYSTEM' => '1',
    'GIT_AUTHOR_NAME' => 'Test', 'GIT_AUTHOR_EMAIL' => 'test@example.com',
    'GIT_COMMITTER_NAME' => 'Test', 'GIT_COMMITTER_EMAIL' => 'test@example.com'
  }.freeze

  def run_tool(name, *, dir:)
    Open3.capture3(GIT_ENV, RbConfig.ruby, File.join(TOOLS, name), *, chdir: dir, stdin_data: '')
  end

  def git(dir, *args)
    out, err, status = Open3.capture3(GIT_ENV, 'git', *args, chdir: dir)
    assert status.success?, "git #{args.join(' ')}: #{err}"
    out
  end

  # A bare remote with one commit, and two clones tracking it: "me" and "coauthor".
  def with_remote
    Dir.mktmpdir('latex-git-') do |root|
      git(root, 'init', '-q', '--bare', '-b', 'master', 'remote.git')
      %w[me coauthor].each { |c| git(root, 'clone', '-q', 'remote.git', c) }
      me = File.join(root, 'me')
      File.write(File.join(me, 'paper.tex'), "one\ntwo\nthree\n")
      git(me, 'add', '.')
      git(me, 'commit', '-qm', 'init')
      git(me, 'push', '-q', '-u', 'origin', 'master')
      git(File.join(root, 'coauthor'), 'pull', '-q', 'origin', 'master')
      yield me, File.join(root, 'coauthor')
    end
  end

  def edit_and_push(clone, from, to)
    path = File.join(clone, 'paper.tex')
    File.write(path, File.read(path).sub(from, to))
    git(clone, 'commit', '-qam', "edit #{to}")
    git(clone, 'push', '-q', 'origin', 'HEAD:master')
  end

  def test_help_flags_and_unknown_options
    Dir.mktmpdir('latex-git-') do |dir|
      %w[git_latex_setup git_latex_sync].each do |tool|
        HELP_FLAGS.each do |flag|
          out, _err, status = run_tool(tool, flag, dir: dir)
          assert status.success?, "#{tool} #{flag}"
          assert_match(/\Ausage: #{tool}/, out)
          assert_match(/WORKFLOW/, out)
        end
        _out, err, status = run_tool(tool, '-bogus', dir: dir)
        refute status.success?
        assert_match(/Unknown option: -bogus/, err)
      end
    end
  end

  def test_setup_refuses_without_tex_and_inits_with_tex
    Dir.mktmpdir('latex-git-') do |dir|
      _out, err, status = run_tool('git_latex_setup', dir: dir)
      refute status.success?
      assert_match(/refusing to git init/, err)
      refute File.exist?(File.join(dir, '.git'))

      File.write(File.join(dir, 'paper.tex'), "x\n")
      out, err, status = run_tool('git_latex_setup', dir: dir)
      assert status.success?, err
      assert_match(/init +new git repo/, out)
      assert_match(/no remote/, err)
    end
  end

  def test_setup_is_idempotent_and_keeps_figures_addable
    with_remote do |me, _|
      FileUtils.mkdir_p(File.join(me, 'figs'))
      File.write(File.join(me, '.gitignore'), "*.aux\n*.aux\n")
      File.write(File.join(me, 'paper.bbl'), "bbl\n")
      git(me, 'add', '-f', 'paper.bbl')
      git(me, 'commit', '-qm', 'bbl')

      out, err, status = run_tool('git_latex_setup', dir: me)
      assert status.success?, err
      assert_match(/untrack paper\.bbl/, out)
      ignore = File.read(File.join(me, '.gitignore'))
      assert_equal 1, ignore.lines.count("*.aux\n")
      assert_equal 'true', git(me, 'config', '--local', 'pull.rebase').chomp

      out, _err, status = run_tool('git_latex_setup', dir: me)
      assert status.success?
      assert_equal ignore, File.read(File.join(me, '.gitignore'))
      refute_match(/^  (set|added|untrack|moved) /, out)

      %w[paper.pdf x.bak paper.bbl].each { |f| assert_equal f, git(me, 'check-ignore', f).chomp }
      _o, _e, ignored = Open3.capture3(GIT_ENV, 'git', 'check-ignore', '-q', 'figs/fig.pdf', chdir: me)
      refute ignored.success?, 'PDFs under figs/ must stay addable'
    end
  end

  def test_setup_moves_figure_exception_after_pdf_pattern
    with_remote do |me, _|
      File.write(File.join(me, '.gitignore'), "!**/figs/**/*.pdf\n*.pdf\n")
      _out, err, status = run_tool('git_latex_setup', dir: me)
      assert status.success?, err
      lines = File.read(File.join(me, '.gitignore')).lines.map(&:chomp)
      assert_operator lines.rindex('!**/figs/**/*.pdf'), :>, lines.rindex('*.pdf')
      assert_equal 1, lines.count('!**/figs/**/*.pdf')
    end
  end

  def test_sync_requires_upstream
    Dir.mktmpdir('latex-git-') do |dir|
      git(dir, 'init', '-q')
      _out, err, status = run_tool('git_latex_sync', dir: dir)
      refute status.success?
      assert_match(/No upstream/, err)
    end
  end

  def test_sync_commits_merges_and_pushes
    with_remote do |me, coauthor|
      out, _err, status = run_tool('git_latex_sync', dir: me)
      assert status.success?
      assert_match(/Up to date/, out)

      edit_and_push(coauthor, 'one', 'ONE')
      File.write(File.join(me, 'paper.tex'), File.read(File.join(me, 'paper.tex')).sub('three', 'THREE'))
      File.write(File.join(me, 'intro.tex'), "intro\n")
      File.write(File.join(me, 'notes.zip'), "zip\n")
      out, err, status = run_tool('git_latex_sync', '--no-compile', dir: me)
      assert status.success?, err
      assert_match(/\+ intro\.tex/, out)
      assert_match(/notes\.zip/, out)
      assert_match(/Pushed/, out)
      assert_equal "notes.zip\n", git(me, 'ls-files', '--others', '--exclude-standard')

      git(coauthor, 'pull', '-q', '--no-rebase')
      assert_equal "ONE\ntwo\nTHREE\n", File.read(File.join(coauthor, 'paper.tex'))
    end
  end

  def test_sync_stops_on_conflict_without_terminal
    with_remote do |me, coauthor|
      edit_and_push(coauthor, 'two', 'THEIR two')
      File.write(File.join(me, 'paper.tex'), File.read(File.join(me, 'paper.tex')).sub('two', 'MY two'))
      _out, err, status = run_tool('git_latex_sync', '--no-compile', dir: me)
      refute status.success?
      assert_match(/Conflicts in: paper\.tex/, err)
      git(me, 'fetch', '-q')
      refute_match(/MY two/, git(me, 'show', 'origin/master:paper.tex'), 'nothing may be pushed')

      out, _err, status = run_tool('git_latex_sync', '-info', dir: me)
      assert status.success?
      assert_match(/MERGE IN PROGRESS/, out)
    end
  end

  def test_info_reports_remote_state
    with_remote do |me, coauthor|
      edit_and_push(coauthor, 'one', 'ONE')
      out, _err, status = run_tool('git_latex_sync', '-info', dir: me)
      assert status.success?
      assert_match(/Remote: +origin -> the remote/, out)
      assert_match(/ahead by 1 commit/, out)
      assert_match(/Local: +nothing unpushed/, out)
      assert_equal 'init', git(me, 'log', '-1', '--format=%s').chomp, '-info must not merge'
    end
  end
end
