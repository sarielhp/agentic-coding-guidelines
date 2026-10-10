# Ruby Engineering Standards & Tooling

This directory defines the authoritative architecture, cognitive complexity boundaries, and automated tooling for Ruby projects.

## Directory Structure

```text
~/prog/standards/ruby/
├── README.md                 # Quick overview & installation guide
├── GUIDELINES.md             # Operational AI Agentic Ruby Architecture Guide
├── RATIONALE.md              # Empirical philosophy, cognitive science & anti-patterns
├── bin/                      # Shared standalone CLI tools
│   ├── ruby-audit            # Sizing & cognitive complexity AST auditor
│   ├── ruby-static-analysis  # Multi-linter orchestrator (rubocop, bundle-audit, dupl)
│   └── ruby-install-tools    # Installs development gems and CLI tools
└── templates/                # Reusable project workflow templates (install under tools/ without .rb)
    ├── Makefile.snippet      # Standard Makefile quality targets
    ├── build.rb              # tools/build: ruby -cw over bin/, lib/, tools/ (no tests, no linters)
    ├── gate.rb               # tools/gate: build, ruby-audit, RuboCop, tests (tools/check = symlink)
    ├── commit.rb             # tools/commit: gated commit, records .verified_head, pushes
    ├── bump.rb               # tools/bump: semver bump, gate (or trusted .verified_head), tag, push, install
    ├── install.rb            # tools/install: copy or --link bin/* into ~/bin (runs tools/build first)
    └── dot_rubocop.yml       # Balanced RuboCop baseline (instantiate as .rubocop.yml; version from .ruby-version)
```

## Project Layout Convention

- `bin/<name>` — executables. A single-file CLI keeps its `VERSION = 'x.y.z'` constant here and exposes `--version`; `tools/bump` finds it there when there is no `lib/**/version.rb`.
- `lib/` — library code, `test/*_test.rb` or `test/test_*.rb` — minitest suites run by `tools/gate` with `-Ilib:test`.
- `tools/` — the lifecycle scripts below; `.ruby-version` pins the interpreter for RuboCop and mise/rbenv.

## Project Bootstrap

```bash
mkdir -p tools
for t in build gate commit bump install; do cp ~/prog/standards/ruby/templates/$t.rb tools/$t; done
chmod +x tools/*
ln -sf gate tools/check                               # compatibility alias
cp ~/prog/standards/ruby/templates/dot_rubocop.yml .rubocop.yml
ruby -e 'puts RUBY_VERSION' > .ruby-version
review-cycle --setup                                   # review contract, .gitignore, AGENTS.md
```

| Command | Role |
|---|---|
| `tools/build` | Syntax-validate every Ruby source. Repo-local, side-effect free. |
| `tools/gate` | Tier 1 gate: build, `ruby-audit`, RuboCop, tests. |
| `tools/commit -m "..."` | Gate, stage, commit, record `.verified_head`, push. |
| `tools/bump [--minor\|--major]` | Bump VERSION, gate (skipped when `.verified_head` == HEAD and only the version changed), tag, push, install. |
| `tools/install [--link]` | Build, then copy or symlink `bin/*` into `~/bin`. |

## Tooling Quick Reference

| Tool | Purpose | Primary Triggers |
|---|---|---|
| `ruby-audit [paths...]` | Audits methods against cognitive limits (depth $\le 4$, CC $\le 15$, tiered lines), file sizing (800/1100), and terminal `else`. | Pre-commit / `make audit` |
| `ruby-static-analysis [paths...]` | Runs `ruby -cw` syntax checks, `rubocop`, `bundle-audit`, and `dupl` clone detector. | Periodic / `make review` |
| `ruby-install-tools` | Audits and installs core development gems (`rubocop`, `ruby-lsp`, `bundler-audit`, `rainbow`, `minitest`). | Once per machine |

## Installation & Linking to `~/bin/`

To make these tools globally available from anywhere in your shell and Makefiles:

```bash
mkdir -p ~/bin
ln -sf ~/prog/standards/ruby/bin/ruby-audit ~/bin/ruby-audit
ln -sf ~/prog/standards/ruby/bin/ruby-static-analysis ~/bin/ruby-static-analysis
ln -sf ~/prog/standards/ruby/bin/ruby-install-tools ~/bin/ruby-install-tools
chmod +x ~/prog/standards/ruby/bin/*
```

## Agent Configuration (`~/.gemini/AGENTS.md`)

Add the following to your global agent instructions:

```markdown
## Ruby Engineering Standards
- **Guidelines**: For any Ruby script or project, strictly adhere to the architecture, cognitive complexity limits, and idiomatic conventions defined in `~/prog/standards/ruby/GUIDELINES.md`.
- **Rationale**: Consult `~/prog/standards/ruby/RATIONALE.md` for cognitive load foundations, block scoping rules, and anti-decomposition constraints.
- **Validation**: Enforce compliance before committing: run `ruby -cw` and `ruby-audit` for standalone scripts (<= 150 lines); run `ruby-static-analysis` only for projects or scripts > 150 lines (see `GUIDELINES.md` §7).
```
