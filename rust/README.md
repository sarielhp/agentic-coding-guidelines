# Rust Engineering Standards & Tooling

This directory defines the authoritative architecture, cognitive complexity boundaries, and automated tooling for Rust projects.

## Directory Structure

```text
~/prog/standards/rust/
├── README.md                 # Quick overview & installation guide
├── GUIDELINES.md             # Operational AI Agentic Rust Architecture Guide
├── RATIONALE.md              # Empirical philosophy, cognitive science & anti-patterns
├── bin/                      # Shared standalone CLI tools
│   ├── rust-audit            # Sizing, cognitive complexity & unwrap/safety auditor
│   ├── rust-static-analysis  # Multi-linter static analysis orchestrator (clippy, audit, deny, machete, geiger)
│   └── rust-install-tools    # Installs cargo audit tools into ~/.cargo/bin/
└── templates/                # Reusable project workflow templates
    ├── check.rb              # Pre-commit CI quality gate script (Tier 1)
    ├── commit.rb             # Gated commit with .verified_head
    ├── bump.rb               # 3-Tier milestone version bump & install script
    ├── install.rb            # Direct cargo install --root ~ script
    └── Makefile.snippet      # Standard Makefile quality targets
```

## Tooling Quick Reference

| Tool | Purpose | Primary Triggers |
|---|---|---|
| `rust-audit [dir]` | Audits functions against cognitive limits (depth $\le 4$, branches $\le 15$, tiered lines), `.unwrap()` violations, terminal `else`, and bare `unsafe`. | Pre-commit / `make audit` |
| `rust-static-analysis [dir]` | Runs `cargo clippy`, `cargo audit`, `cargo deny`, `cargo machete`, and `cargo geiger`. | Periodic / Milestone / `make review` |
| `rust-install-tools` | Installs external analysis cargo binaries into `~/.cargo/bin/`. | Once per machine |

## Installation & Linking to `~/bin/`

To make these tools globally available from anywhere in your shell and Makefiles:

```bash
mkdir -p ~/bin
ln -sf ~/prog/standards/rust/bin/rust-audit ~/bin/rust-audit
ln -sf ~/prog/standards/rust/bin/rust-static-analysis ~/bin/rust-static-analysis
ln -sf ~/prog/standards/rust/bin/rust-install-tools ~/bin/rust-install-tools
chmod +x ~/prog/standards/rust/bin/*
```

## Agent Configuration (`~/.gemini/AGENTS.md`)

Add the following to your global agent instructions:

```markdown
## Rust Engineering Standards
- **Guidelines**: For any Rust project, strictly adhere to the architecture, cognitive complexity limits, `let-else` guard idioms, and anti-clone rules defined in `~/prog/standards/rust/GUIDELINES.md`.
- **Rationale**: Consult `~/prog/standards/rust/RATIONALE.md` for the empirical reasoning, borrow-checker anti-decomposition constraints, and 3-tier milestone strategy.
- **Validation**: Enforce compliance before committing using `rust-audit` (sizing, complexity & unwrap/unsafe audit) and `rust-static-analysis` (clippy, CVEs, supply-chain & unsafe review).
```
