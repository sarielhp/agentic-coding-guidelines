# Ruby engineering standards and tooling

[GUIDELINES.md](GUIDELINES.md) defines method/file tiers, cognitive limits, idioms, standalone scope, and the lifecycle. [RATIONALE.md](RATIONALE.md) explains the rules. Existing architecture and sizing limits remain in force.

`bin/ruby-audit` is the standalone AST auditor. `bin/ruby-static-analysis` runs syntax, RuboCop, and scoped dependency/clone review. Keep `bin/analysis_support.rb` beside the wrapper. `ruby-install-tools --check-only` audits without creating directories and exits nonzero when required gems are missing. The installer adds Ruby-capable [Flay](https://github.com/seattlerb/flay) to the development gem list. Bootstrap or symlink installation requires separate authorization; gates never install tools.

`templates/` contains entry points, copied helpers (`tooling.rb`, `language.rb`), `settings.rb`, `AGENTS_SNIPPET.md`, `Makefile.snippet`, and `dot_rubocop.yml`. Shared portable acceptance tests live in `../test/`.

## Adopt the workflow

Copy every Ruby template, preserving `.rb` on `settings.rb`, `tooling.rb`, and `language.rb`. Entry points are installed without `.rb`:

```bash
rtk proxy mkdir -p tools
for source in ~/prog/standards/ruby/templates/*.rb; do
  name=${source##*/}
  case "$name" in settings.rb|tooling.rb|language.rb) ;; *) name=${name%.rb} ;; esac
  rtk proxy cp "$source" "tools/$name"
done
rtk proxy chmod +x tools/build tools/lint tools/test tools/gate tools/check tools/snapshot tools/commit tools/bump tools/install tools/release
```

Read and adapt `tools/settings.rb`. Include `templates/Makefile.snippet` in the project Makefile; targets delegate to canonical scripts. Copy [templates/AGENTS_SNIPPET.md](templates/AGENTS_SNIPPET.md) into project agent instructions. The helpers are copied project assets; updating this standards repository does not upgrade existing projects automatically.

| Entry point | Contract |
|---|---|
| `build`, `lint`, `test` | Separate build, static feedback, and test commands. |
| `gate`, `check` | One fast gate; `--full` adds release analysis. |
| `snapshot [message]` | Ungated local checkpoint, bypassing commit hooks. |
| `commit [--full] <message>` | Verified local commit; no push. |
| `bump [major\|minor\|patch]` | Full-checked version change and verified atomic upstream publication. |
| `bump --resume` | Resume an inspected failed release without another version change. |
| `install [names...]` | Build and verify only declared installation targets. |
| `release [--install] <message>` | Commit and publish a patch release; installation opt-in. |

Use `rtk proxy tools/<command>` for these entry points. Pass the commit message as one literal argument. Use scripts directly for messages containing shell metacharacters; Make interpolation is not an escaping boundary. `tools/check` delegates to `tools/gate`, and `make ci` delegates to the full gate.

## Release and installation configuration

Releases require an attached branch, its configured remote branch upstream, and exactly one push URL. Bumps require a clean tree and strict `major.minor.patch` version. Full checks run after all version-dependent files are updated. The requested annotated tag and exact commit go to the configured upstream branch; remote SHA verification includes the peeled tag. Unrelated tags remain local. Missing analyzers, failed stages, unsupported atomic push, or remote mismatch fail the command.

Interrupted releases retain `.git/tooling-release.json`. Inspect the failure and local state, repair the cause, then run `tools/bump --resume`. It never increments the pending version. It rejects changed committed inputs; do not bypass this by editing the verification record. Legacy `.verified_head` markers are ignored.

`INSTALL_TARGETS = { 'artifact/path' => '/absolute/authorized/destination' }.freeze` declares installation scope. The default empty mapping disables installation. Targets must refer to declared `ARTIFACTS`, or language-discovered artifacts. Installation runs `tools/build` and verifies installed content and permissions. A declaration describes scope; user authorization and sandbox permissions still govern external writes.

Set `TOOLS` overrides when an executable is not on PATH. Additional `FAST_CHECKS`, `FULL_CHECKS`, and `VERSION_UPDATE` commands are argument arrays. Freeze nested arrays as well as the outer array. Add ignored inputs to `VERIFICATION_INPUTS`; they participate in verification. Tool bootstrap remains a separate authorized step.

## Migration from the old templates

Replace the entry points together with their helpers; do not mix old and new script versions. Commits are local, bumps always perform full checks, and install targets must be declared. Bumps no longer install automatically. Use positional `major`/`minor`/`patch` instead of legacy flags, and use `release --install` only for an authorized installation. Release artifacts stay inside the repository until the explicit installer copies them.

The `--strict` analyzer option remains accepted, but failures now always exit nonzero. No analyzer is silently skipped or installed by a gate. Reconcile project-specific checks, version generation, and existing installation targets in settings before replacing scripts.
## Ruby layouts, profiles, and tests

Projects default to `PROFILE = :project`. Copy `templates/dot_rubocop.yml` to `.rubocop.yml` and pin the interpreter in `.ruby-version`. `SOURCE_GLOBS` covers executables, libraries, tools, tests, gemspecs, and Rakefile; adapt it for other layouts. A root executable named after the repository is also discovered. `tools/build` checks syntax with warnings enabled and treats warnings as failures. It creates no installed artifact.

One application script at most 150 lines without `Gemfile.lock` may select `PROFILE = :script`; it uses syntax and strict AST audit. More application sources, larger source files, or a lockfile promote it to project checks. Copied lifecycle scripts alone do not promote it. Projects require RuboCop; full gates additionally require Flay and bundle-audit when a lockfile exists. Missing tools fail rather than reducing coverage.

`TEST_GLOBS` defaults to both conventional minitest naming patterns. All matches are deduplicated and loaded in one Ruby process with `-Ilib:test`, through Bundler when a Gemfile exists. Set `TEST_COMMAND = ['bundle', 'exec', 'rspec'].freeze` or an explicit Rake command for another framework. Test failures never invoke a fallback. An empty selection is printed explicitly.

`ARTIFACTS = nil` discovers executable Ruby files directly in `bin/`; specify paths for other layouts or `[]` for a pure library. `tools/install --link [names...]` supports declared development symlinks and verifies their target. An existing intended link can be updated; unrelated symlinks are rejected. The old `--dest` override is replaced by declared `INSTALL_TARGETS`.

Versions are discovered from exactly one conventional `lib/**/version.rb`, root `version.rb`, or `bin/*` VERSION definition. Configure `VERSION_FILE` when ambiguous or elsewhere. Constant mode edits one literal `VERSION` assignment, leaving unrelated numeric literals alone. `VERSION_STYLE = :text` supports an explicitly selected metadata file such as `VERSION`; declare application-version generation in `VERSION_UPDATE` when required.

`ruby-static-analysis` searches upward from targets for project RuboCop configuration, falling back to the standards baseline and running interpreter version. Default single-file review omits dependency and clone checks; explicit flags can request them. `--dups` uses Flay with mass threshold 50 (override with `--threshold`); clone findings, parser skips, invalid reports, and execution failures stop review. The old Go `dupl` adapter is removed.
