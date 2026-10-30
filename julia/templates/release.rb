#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative 'tooling'

HELP = <<~TEXT
  Usage: tools/release [--install] <message>

  Release: commit, bump the patch version, push, and optionally install.

    1. Commit the pending work as <message>, after the fast gate (tools/commit).
    2. Bump the patch version in Project.toml, run the full gate, commit
       "chore: bump version to X.Y.Z" and push the branch, verified
       (tools/bump). The vX.Y.Z tag is pushed too only when RELEASE_TAG is set.
    3. With --install, install the declared scripts to INSTALL_TARGETS
       (tools/install).

  A release does not register the package; that is tools/publish, run rarely
  and only on request. Steps 1 and 2 change the remote repository and are not
  undone by rerunning. If a step fails, the message says what was published;
  an interrupted bump is finished with tools/bump --resume.

  Options:
    --install   Also install to the targets declared in tools/settings.rb.
    -h, --help  Show this help; nothing is run.
TEXT

Tooling.entry(HELP) do
  install_requested = ARGV.first == '--install'
  ARGV.shift if install_requested
  abort 'Usage: tools/release [--install] <message>' unless ARGV.length == 1
  Tooling.release(Tooling.commit_message(ARGV.first), install_requested)
end
