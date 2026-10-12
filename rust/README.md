# Rust engineering standards and tooling

[GUIDELINES.md](GUIDELINES.md) defines architecture, cognitive limits, idioms, and the lifecycle. [RATIONALE.md](RATIONALE.md) explains the design. Existing sizing, unwrap, unsafe, and borrow-checker rules remain in force.

`bin/rust-audit` is the standalone sizing/idiom auditor. `bin/rust-static-analysis` runs required Clippy, cargo-audit, cargo-deny, and cargo-machete review; flags select individual checks. `bin/analysis_support.rb` must remain beside the wrapper. `rust-install-tools` is the separately invoked tool bootstrapper. Run them by absolute path or explicitly authorize symlink installation into `~/bin`; this workflow does not install them automatically.

`templates/` contains the entry points, copied `tooling.rb`/`language.rb` helpers, `settings.rb`, `AGENTS_SNIPPET.md`, `Makefile.snippet`, and optional `clippy.toml`. Portable shared acceptance tests live in `../test/`.

## Adopt the workflow

Copy every Ruby template, preserving `.rb` on `settings.rb`, `tooling.rb`, and `language.rb`. Entry points are installed without `.rb`:

```bash
rtk proxy mkdir -p tools
for source in ~/prog/standards/rust/templates/*.rb; do
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
## Cargo layouts and milestone suites

The default build uses `--workspace` and discovers workspace binary targets through Cargo metadata. Root binaries, explicit `[[bin]]` layouts, multi-binary workspaces, and library-only packages are supported. Declared binary outputs must exist and be executable after the build. For a library use `ARTIFACTS = []`; installation remains disabled. For cross compilation, set `BUILD_ARGS` (for example `['--workspace', '--target', 'aarch64-unknown-linux-gnu'].freeze`) and explicit artifact paths beneath the configured target directory. Ignore generated build outputs in the project `.gitignore`; gates reject changes to checked source/configuration inputs.

`TARGET_DIR` defaults to `target` and must stay inside the repository, including through symlinks. It overrides external `CARGO_TARGET_DIR` and Cargo configuration for build/test/Clippy commands. Never hide an escaping output directory in `BUILD_ARGS`. Dependency/compiler caches can remain outside the repository. Cargo operations are offline and locked; prepare caches and commit a lockfile before running normal checks. Version synchronization runs offline Cargo check without `--locked` before the full release gate so the changed lockfile is checked and committed.

`VERSION_FILE` defaults to `Cargo.toml`, `VERSION_SECTION` to `package`. An inherited workspace version requires `VERSION_SECTION = 'workspace.package'` and the root workspace manifest. Only the literal version in the selected section is edited. Existing `VERSION` and `CHANGELOG.md` metadata are updated; declare other generation in `VERSION_UPDATE`.

`BUMP_STATE` defaults to `.bump_state.json` and records the release count/version before checks. Set `BENCHMARK = ['tools/benchmark', '--rust-only'].freeze` for required fifth-bump benchmarks and `DEEP_TEST = ['tools/test_deep'].freeze` for twentieth-bump integration. `nil` disables a suite explicitly. Failures preserve pending state for inspection and resume.

Full review requires cargo-audit, cargo-deny, and cargo-machete. The compiler and sizing auditor's unsafe rules remain in force. `rust-static-analysis --dups` requires an executable project `tools/check_duplicates` implementing Rust clone review; the old Go `dupl` fallback is removed. Optional `--outdated` and `--semver` require their corresponding Cargo plugins.
