# Go Engineering Standards & Tooling

This directory defines the authoritative architecture, cognitive complexity boundaries, and automated tooling for Go projects.

## Directory Structure

```text
~/prog/standards/go/
├── README.md               # Quick overview & installation guide
├── GUIDELINES.md           # Operational AI Agentic Go Architecture Guide
├── RATIONALE.md            # Empirical philosophy, cognitive science & anti-patterns
├── bin/                    # Shared standalone CLI tools
│   ├── go-audit            # Sizing & cognitive complexity auditor
│   ├── go-static-analysis  # Multi-linter static analysis orchestrator
│   └── go-install-tools    # Installs linters into ~/.go/bin/
├── test/                   # Isolated build, gate, lifecycle, and failure fixtures
└── templates/              # Reusable project workflow templates
    ├── Makefile.snippet    # Delegates to canonical repository commands
    ├── AGENTS_SNIPPET.md   # Agent command forms and authorization boundaries
    ├── settings.rb         # Explicit project adaptation choices
    ├── tooling.rb          # Copied shared implementation (no live checkout dependency)
    ├── build.rb            # Artifact-only build for root apps, libraries, cmd layouts
    ├── gate.rb / check.rb  # One fast/full quality gate implementation
    ├── lint.rb             # Vet, baseline staticcheck, strict cognitive audit
    ├── snapshot.rb         # Local checkpoint without gate or push
    ├── commit.rb           # Gated local commit and structured verification
    ├── bump.rb             # Patch bump, verified push, interrupted-push resume
    ├── install.rb          # Declared targets and installed-content verification
    └── release.rb          # Commit, full-checked bump, optional installation
```

## Tooling Quick Reference

| Tool | Purpose | Primary Triggers |
|---|---|---|
| `go-audit [dir]` | Audits functions against cognitive limits (depth $\le 4$, branches $\le 15$, tiered lines). | Pre-commit / `make audit` |
| `go-static-analysis [dir]` | Runs `gocritic`, `shadow`, `revive`, `govulncheck`, and `dupl`. | Periodic / `make review` |
| `go-install-tools` | Installs staticcheck and deep analyzers using configured Go installation locations. | Separately authorized bootstrap |

## Adopt the Repository Interface

Read [GUIDELINES §8](GUIDELINES.md#8-repository-tooling-interface) for the contract.
From an authorized project's root, copy the templates rather than linking to a
live standards checkout:

```bash
mkdir -p tools
for t in build gate check lint snapshot commit bump install release; do
  cp ~/prog/standards/go/templates/$t.rb tools/$t
  chmod +x tools/$t
done
cp ~/prog/standards/go/templates/settings.rb tools/settings.rb
cp ~/prog/standards/go/templates/tooling.rb tools/tooling.rb
```

`tools/check` loads `tools/gate`; alternatively use a `check -> gate` symlink.
Include or adapt `Makefile.snippet` and `AGENTS_SNIPPET.md`. Both entry points
remain compatible with review-cycle. Bootstrap Go and required analysis tools
separately; running a gate never installs a missing tool.

Edit `tools/settings.rb` before use:

- `BUILD_PACKAGES` validates `./...` by default. `ARTIFACTS = nil` detects a
  root main package and produces `bin/<directory-name>`. Set `{}` for a library,
  or `{ 'bin/example' => './cmd/example' }` for a cmd layout; `{ 'example' => '.' }`
  produces a root binary. Ignore every declared artifact in `.gitignore`.
- `TOOLS` overrides individual executable paths. Otherwise GOBIN, GOPATH/bin,
  normal PATH, `~/.go/bin`, and `~/go/bin` resolve tools without shell wrappers.
- `INSTALL_TARGETS` maps declared artifacts to absolute authorized destinations.
  The empty default clearly rejects installation. It copies and compares bytes
  and permissions, rejecting destination symlinks; it does no unrelated cleanup.
- `VERSION_FILE` defaults to `VERSION` and requires strict `major.minor.patch`.
  `VERSION_KIND = :embedded` conservatively runs full checking after the bump.
  `VERSION_UPDATE` contains explicit command arrays for source version updates,
  generators, or project-specific metadata. They run before full checking.
- Set `VERSION_KIND = :metadata` only for standalone metadata. Reuse requires
  unchanged full verification, no version-update commands, and `go list` showing
  that the version file is not embedded. Reused checks still rebuild artifacts.
- `FAST_CHECKS` and `FULL_CHECKS` are additional checked command arrays.
  `VERIFICATION_INPUTS` declares paths/globs for ignored inputs those checks read.
  Extend the digest for additional relevant environment or external dependencies.

All artifact paths and existing ancestors are checked before builds write. Go
caches are independent of artifact containment. Pure libraries can leave install
and versioned releases unsupported. These examples define project choices;
they do not migrate an existing repository or change its authorization policy.

## Commands and Failures

```bash
rtk proxy tools/build
rtk proxy tools/lint
rtk proxy tools/check                  # fast checks and tests, then build
rtk proxy tools/gate --full             # additionally race, vulnerability, deep checks
rtk proxy tools/snapshot "chore: checkpoint"
rtk proxy tools/commit 'fix: literal message'  # local commit; no push
rtk proxy tools/commit --full 'fix: reviewed change'
rtk proxy tools/bump                   # full verification, bump, commit, verified push
rtk proxy tools/release 'fix: release'  # fast commit gate, one full bump gate
rtk proxy tools/release --install 'fix: release'
rtk proxy tools/install                # separate, explicitly authorized operation
```

Gates check formatting rather than modifying sources. Fast checking runs module
tidiness, vet, staticcheck, `go-audit --strict`, project checks, tests, and build.
Full checking adds race tests, govulncheck, gocritic, shadow, revive, dupl, and full
project checks. The deep checks invoke required analyzers directly because the
legacy advisory `go-static-analysis` can skip missing tools. That shared analyzer
is preserved; gates enforce subprocess status and findings themselves.

There are no bundled exceptions. `tools/staticcheck-baseline.txt` contains one
exact JSON diagnostic per line (from `staticcheck -f json ./...`);
`tools/go-audit-baseline.txt` contains exact ANSI-free `[FAIL]` lines. Counts matter:
two identical findings require two deliberately reviewed entries. New findings,
execution errors, empty failure reports, malformed JSON, or missing tools fail.
No script writes or enlarges a baseline. Deep findings fail; projects with
reviewed deep exceptions must explicitly adapt the relevant checks.

Verification resides in Git's `tooling-verification.json`, with HEAD, gate level,
content/mode digest, Go configuration, and executable identities. Fast records
and old `.verified_head` markers never establish full verification. Commit hooks
that change inputs block verification. A source change cannot become safe merely
because its filename was declared version metadata.

Bump preflights version format, clean state, and branch/upstream settings. It
requires one configured upstream push URL and explicitly pushes `SHA:refs/heads/…`
to that URL, then queries the same URL and ref. It does not force, pull, rebase,
tag, or install. Local changes and a pending-release record survive failures.
If push or remote verification fails, inspect the commit and retry:

```bash
rtk proxy tools/bump --resume
```

Resume never increments the version. If failure occurred before a release commit,
repair the issue and inspect pending state, then resume runs a full gate and
completes that version's commit. It requires the original HEAD and pending version
to match; unexpected history changes require manual inspection. Do not rerun an
ordinary bump. Release requires a
message and stops at each failed stage. A verified push followed by install
failure is reported as installation failure after publication; retry install
separately. Make delegates accept ordinary shell arguments; use the direct Ruby
entry point for commit messages containing shell metacharacters.

## Template Acceptance Tests

```bash
rtk proxy ruby -I go/test -e 'Dir.glob("go/test/*_test.rb").sort.each { |path| require_relative path }'
rtk proxy ruby/bin/ruby-audit --strict --include-tests go/templates go/test go/bin/go-install-tools
rtk proxy ruby/bin/ruby-static-analysis --strict go/templates go/test go/bin/go-install-tools
```

Tests require Ruby with minitest, Git, Make, and Go 1.26+ for the real fixture.
All fixture applications, libraries, build outputs, cache, installation targets,
and bare remotes live in temporary directories and are cleaned up. Controlled
analyzer shims exercise failure paths; the Go fixture uses the real compiler,
format checker, module checks, vet, tests, and race detector. Analyzers are not
installed and no user's remote or installation target is used.

## Installation & Linking to `~/bin/`

To make these tools globally available from anywhere in your shell and Makefiles:

```bash
mkdir -p ~/bin
ln -sf ~/prog/standards/go/bin/go-audit ~/bin/go-audit
ln -sf ~/prog/standards/go/bin/go-static-analysis ~/bin/go-static-analysis
ln -sf ~/prog/standards/go/bin/go-install-tools ~/bin/go-install-tools
chmod +x ~/prog/standards/go/bin/*
```

## Agent Configuration (`~/.gemini/AGENTS.md`)

Add the following to your global agent instructions:

```markdown
## Go Engineering Standards
- **Guidelines**: For any Go project, strictly adhere to the architecture, cognitive complexity limits, and Google Go style rules defined in `~/prog/standards/go/GUIDELINES.md`.
- **Rationale**: Consult `~/prog/standards/go/RATIONALE.md` for the empirical reasoning, cognitive tiering justification, and anti-decomposition rules.
- **Validation**: Enforce compliance before committing using `go-audit` (sizing & cognitive complexity) and `go-static-analysis` (deep AST, symmetries, and security review).
```
