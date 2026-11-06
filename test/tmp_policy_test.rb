# frozen_string_literal: true

require_relative 'tmp_env'
require 'minitest/autorun'

# The standards repository follows its own rule (README, "Temporary and cached files"):
# its programs and templates create temporary files only through ProjectTmp,
# and its tests, whose TMPDIR test/tmp_env.rb points into the tree, name no
# literal /tmp path. A line may opt out with `tmp-exempt: <reason>`.
class TmpPolicyTest < Minitest::Test
  ROOT = File.expand_path('..', __dir__)

  def ruby_program?(path)
    File.file?(path) && (path.end_with?('.rb') || File.open(path, &:gets).to_s.match?(/\A#!.*ruby/))
  end

  def programs
    globs = %w[*/bin/* latex/tools/* */templates/*.rb]
    globs.flat_map { |glob| Dir.glob(File.join(ROOT, glob)) }.select { |path| ruby_program?(path) }
  end

  def tests
    Dir.glob(File.join(ROOT, '{test,go/test}', '*.rb'))
  end

  def test_programs_use_project_tmp
    found = ProjectTmp.offenders(programs, ProjectTmp::RUBY_CALLS, comment: /#.*/)
    assert_empty found, 'create temporary files through ProjectTmp (ruby/templates/tmp_space.rb)'
  end

  def test_tests_name_no_literal_tmp_path
    found = ProjectTmp.offenders(tests, ProjectTmp::RUBY_CALLS, comment: /#.*/, test_file: ->(_) { true })
    assert_empty found
  end

  # Caches are not temporary files: they live in $XDG_CACHE_HOME/<project>/,
  # which test/tmp_env.rb also points into the test run.
  def test_cache_dir_is_under_xdg_cache_home
    path = ProjectTmp.cache_dir('policy-test')
    assert_equal File.join(ENV.fetch('XDG_CACHE_HOME'), 'standards', 'policy-test'), path
    assert File.directory?(path)
    assert path.start_with?(STANDARDS_TEST_RUN), 'tests never write to the real cache'
  end

  def test_tree_layout_and_sweep
    made = ProjectTmp.mktmpdir('policy-test')
    assert_equal File.join(Dir.tmpdir, ProjectTmp.user_name, 'standards', 'policy-test'), File.dirname(made) # tmp-exempt: checks the layout
    old = File.join(ProjectTmp.dir('policy-test'), 'old')
    Dir.mkdir(old)
    File.utime(Time.now - (25 * 3600), Time.now - (25 * 3600), old)
    ProjectTmp.sweep!
    refute File.exist?(old)
    assert File.exist?(made)
  end
end
