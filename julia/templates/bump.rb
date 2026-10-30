#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative 'tooling'

HELP = <<~TEXT
  Usage: tools/bump [major|minor|patch|--resume]

  Release the committed tree. The working tree must be clean.

    1. Raise the version in Project.toml (patch by default) and run
       VERSION_UPDATE.
    2. Run the full gate, commit "chore: bump version to X.Y.Z", and push the
       branch, verified. The vX.Y.Z tag is pushed with it only when
       RELEASE_TAG is set; a registered package is tagged by TagBot instead.

  This changes the remote repository. It neither installs nor registers.

  Options:
    major, minor, patch  Which part of the version to raise.
    --resume    Finish a bump that stopped partway, without bumping the
                version again.
    -h, --help  Show this help; nothing is run.
TEXT

Tooling.entry(HELP) do
  abort 'Usage: tools/bump [major|minor|patch|--resume]' unless ARGV.length <= 1 && (ARGV.empty? || %w[major minor patch
                                                                                                       --resume].include?(ARGV.first))
  ARGV.first == '--resume' ? Tooling.resume : Tooling.bump(ARGV.first || 'patch')
end
