# frozen_string_literal: true

module ToolSettings
  TOOLS = {}.freeze
  PROFILE = :project # :script is for standalone programs <=150 lines without Gemfile.lock.
  SOURCE_GLOBS = ['bin/**/*', 'lib/**/*.rb', 'tools/**/*', 'test/**/*.rb', 'spec/**/*.rb', '*.rb', '*.gemspec', 'Rakefile'].freeze
  TEST_GLOBS = ['test/**/test_*.rb', 'test/**/*_test.rb'].freeze
  TEST_COMMAND = nil # Explicit arrays for RSpec/Rake; default loads every discovered minitest file once.
  ARTIFACTS = nil # Detect executable bin/*; [] explicitly selects a pure library.
  INSTALL_TARGETS = {}.freeze # Artifact => absolute, authorized destination.
  VERSION_FILE = nil # Detect conventional version.rb or bin/*; ambiguity requires an explicit path.
  VERSION_STYLE = :constant # :text supports a standalone VERSION metadata file.
  VERSION_UPDATE = [].freeze
  RELEASE_TAG = true
  FLAY_MASS = 50
  FAST_CHECKS = [].freeze
  FULL_CHECKS = [].freeze
  VERIFICATION_INPUTS = ['.bundle/config', '.ruby-version', '.tool-versions', '.rubocop*', '.flayignore'].freeze
end
