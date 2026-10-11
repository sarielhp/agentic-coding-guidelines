# frozen_string_literal: true

# Copy this file unchanged to tools/settings.rb, then adapt these project choices.
module ToolSettings
  TOOLS = {}.freeze # Optional exact executable paths, e.g. { 'go-audit' => '/path/go-audit' }
  BUILD_PACKAGES = ['./...'].freeze
  # nil detects a root main package; {} explicitly selects a library.
  # For cmd layouts, use { 'bin/example' => './cmd/example' }. Root artifacts work too.
  ARTIFACTS = nil
  INSTALL_TARGETS = {}.freeze # e.g. { 'bin/example' => File.expand_path('~/bin/example') }
  VERSION_FILE = 'VERSION'
  # :embedded conservatively checks the changed version with a full gate.
  # :metadata permits reuse only after go list confirms VERSION is not embedded.
  VERSION_KIND = :embedded
  # Additional generator/version update commands are checked argument arrays.
  VERSION_UPDATE = [].freeze
  FAST_CHECKS = [].freeze
  FULL_CHECKS = [].freeze
  TEST_TIMEOUT = '180s'
  VERIFICATION_INPUTS = [].freeze # Explicit extra paths/globs for ignored inputs read by project checks.
end
