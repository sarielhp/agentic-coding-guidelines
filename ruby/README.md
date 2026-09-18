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
└── templates/                # Reusable project workflow templates
    ├── Makefile.snippet      # Standard Makefile quality targets
    ├── check.rb              # Pre-commit CI quality gate script
    ├── commit.rb             # Gated commit with .verified_head
    ├── bump.rb               # Semver bump & tag script
    └── .rubocop.yml          # Balanced RuboCop configuration aligned with guidelines
```

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
- **Validation**: Enforce compliance before committing using `ruby-audit` (AST sizing & cognitive complexity) and `ruby-static-analysis` (syntax, style, and CVE review).
```
