# frozen_string_literal: true

# Load first in every test file (before minitest, whose at_exit runs the
# tests): TMPDIR and XDG_CACHE_HOME for this process and every program it
# starts point into <tmpdir>/<user>/standards/test-run/, removed when the
# process exits, so tests touch neither the system temporary directory nor
# the user's real cache.
require 'fileutils'
require_relative '../ruby/templates/tmp_space'

ProjectTmp.project = 'standards'
STANDARDS_TEST_RUN = ProjectTmp.mktmpdir('test-run')
ENV['TMPDIR'] = File.join(STANDARDS_TEST_RUN, 'tmp')
ENV['XDG_CACHE_HOME'] = File.join(STANDARDS_TEST_RUN, 'cache')
FileUtils.mkdir_p([ENV.fetch('TMPDIR'), ENV.fetch('XDG_CACHE_HOME')], mode: 0o700)
at_exit { FileUtils.rm_rf(STANDARDS_TEST_RUN) }
