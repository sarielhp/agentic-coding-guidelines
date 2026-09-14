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
└── templates/              # Reusable project workflow templates
    ├── Makefile.snippet    # Standard Makefile quality targets
    ├── check.rb            # Pre-commit CI quality gate script
    ├── commit.rb           # Gated commit with .verified_head
    └── bump.rb             # Semantic patch bump & install script
```

## Tooling Quick Reference

| Tool | Purpose | Primary Triggers |
|---|---|---|
| `go-audit [dir]` | Audits functions against cognitive limits (depth $\le 4$, branches $\le 15$, tiered lines). | Pre-commit / `make audit` |
| `go-static-analysis [dir]` | Runs `gocritic`, `shadow`, `revive`, `govulncheck`, and `dupl`. | Periodic / `make review` |
| `go-install-tools` | Installs external analysis binaries into `~/.go/bin/`. | Once per machine |

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
