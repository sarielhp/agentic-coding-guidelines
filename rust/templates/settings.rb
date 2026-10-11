# frozen_string_literal: true

module ToolSettings
  TOOLS = {}.freeze
  TARGET_DIR = 'target'
  BUILD_ARGS = ['--workspace'].freeze
  ARTIFACTS = nil # Detect workspace binaries; use [] for a library or explicit relative paths for cross builds.
  INSTALL_TARGETS = {}.freeze # Artifact => absolute, authorized destination.
  VERSION_FILE = 'Cargo.toml'
  VERSION_SECTION = 'package' # Set workspace.package for an inherited workspace version.
  VERSION_UPDATE = [].freeze
  RELEASE_TAG = true
  BUMP_STATE = '.bump_state.json'
  BENCHMARK = nil # e.g. ['tools/benchmark', '--rust-only'].freeze; required on each fifth bump when configured.
  DEEP_TEST = nil # e.g. ['tools/test_deep'].freeze; required on each twentieth bump when configured.
  FAST_CHECKS = [].freeze
  FULL_CHECKS = [].freeze
  VERIFICATION_INPUTS = ['.cargo/**/*', 'rust-toolchain*'].freeze
end
