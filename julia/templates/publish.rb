#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative 'tooling'

# Registration is a separate step from releasing on purpose: a release only
# pushes, and is frequent; a registration is public, permanent, and rare.
HELP = <<~TEXT
  Usage: tools/publish [--dry-run] [release notes]

  Register the released version in Julia's General registry. Registration is
  public and cannot be withdrawn: run this rarely, after major or breaking
  changes, and only when explicitly asked. Release first (tools/release).

    1. Check that the tree is clean, that HEAD is the pushed upstream branch,
       and that Project.toml names a package (name and uuid).
    2. Wait for the PUBLISH_WORKFLOW run on that commit to pass.
    3. Comment "@JuliaRegistrator register" on the commit on GitHub, with the
       release notes (default "See CHANGELOG.md.").

  TagBot tags the version and creates the GitHub release once the registration
  merges. The repository needs JuliaRegistrator and TagBot enabled.

  Options:
    --dry-run   Print the version and commit to register; change nothing.
    -h, --help  Show this help; nothing is run.
TEXT

GITHUB_URL = %r{\A(?:https://github\.com/|git@github\.com:|ssh://git@github\.com/)([^/]+/[^/]+?)(?:\.git)?/?\z}
POLLS = 30

def github_repo(destination)
  return ToolSettings::GITHUB_REPO if ToolSettings::GITHUB_REPO

  destination[GITHUB_URL, 1] or raise "cannot tell the GitHub repository from #{destination}; set GITHUB_REPO"
end

# The commit to register is the one already on the remote: registering a
# local commit would publish a version nobody can fetch.
def pushed_commit
  raise 'publish requires a clean working tree' unless Tooling.git('status', '--porcelain').empty?

  destination, ref = begin
    Tooling.upstream
  rescue StandardError => e
    raise "publish needs a branch with a pushed upstream; release first (#{e.message.strip})"
  end
  commit = Tooling.head
  remote = Tooling.git('ls-remote', '--exit-code', destination, ref).split.first
  raise "HEAD #{commit} is not the pushed #{ref} (#{remote}); release first" unless remote == commit

  [destination, commit]
end

def ci_run(gh_cli, repo, commit)
  workflow = ToolSettings::PUBLISH_WORKFLOW
  POLLS.times do
    runs = JSON.parse(Tooling.query(gh_cli, 'run', 'list', '--repo', repo, '--workflow', workflow,
                                    '--commit', commit, '--limit', '1', '--json', 'databaseId'))
    return runs.first.fetch('databaseId').to_s unless runs.empty?

    sleep(Float(ENV.fetch('PUBLISH_POLL_SECONDS', '2')))
  end
  raise "no #{workflow} run for #{commit}; inspect GitHub Actions before registering"
end

def register(gh_cli, repo, commit, notes)
  puts "Waiting for #{ToolSettings::PUBLISH_WORKFLOW} on #{commit}"
  Tooling.run(gh_cli, 'run', 'watch', ci_run(gh_cli, repo, commit), '--repo', repo, '--exit-status', '--interval', '20')
  body = "@JuliaRegistrator register\n\nRelease notes:\n#{notes}"
  Tooling.query(gh_cli, 'api', "repos/#{repo}/commits/#{commit}/comments", '-f', "body=#{body}", '--jq', '.html_url').strip
end

Tooling.entry(HELP) do
  dry_run = ARGV.delete('--dry-run')
  raise "unknown option #{ARGV.first}; see tools/publish --help" if ARGV.first&.start_with?('-')

  notes = ARGV.join(' ').strip
  notes = 'See CHANGELOG.md.' if notes.empty?
  raise 'Project.toml has no name and uuid; only a package can be registered' unless Language.package?

  _, version = Tooling.version
  destination, commit = pushed_commit
  repo = github_repo(destination)
  puts "Register #{repo} #{version} at #{commit}"
  next if dry_run

  url = register(Tooling.executable('gh'), repo, commit, notes)
  puts "Registration requested for #{version}: #{url}"
  puts 'Check the Registrator and AutoMerge results; TagBot tags the version after the registration merges.'
end
