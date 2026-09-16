# Agentic Coding Guidelines & Standards

[![Go Standards](https://img.shields.io/badge/Language-Go-00ADD8?style=flat&logo=go)](go/GUIDELINES.md)
[![Rust Standards](https://img.shields.io/badge/Language-Rust-dea584?style=flat&logo=rust)](rust/GUIDELINES.md)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

Architectural guidelines, cognitive complexity boundaries, and automated quality gates designed specifically for **AI pair programming and autonomous coding agents** (Claude, Gemini, Cursor, Copilot, ChatGPT).

---

## The Problem: The AI Refactoring Trap

When you instruct an autonomous AI coding agent using traditional rules like *"keep functions under 80 lines"*, it optimizes blindly for the line metric rather than software design. 

This causes well-known pathological behaviors:
- **Artificial Continuation Slicing**: An agent chops a coherent 100-line linear algorithm across the middle into meaningless fragments like `processPart1()` and `processPart2()`.
- **Parameter Dumping**: The agent extracts helper functions that take 5–7 local variable pointers just to pass mutable state across an artificial boundary.
- **Context Fragmentation**: Linear logic is scattered across disparate scopes, increasing mental stack depth and degrading the agent's ability to reason about edge cases.
- **Borrow Checker Thrashing (Rust)**: An agent forced to slice a function attempts to appease the borrow checker by inserting `.clone()` or wrapping state in `Arc<Mutex<T>>`.

Raw line counts are a crude proxy for code clarity. **Cognitive complexity** (nesting depth, branch density, and mental state tracking) is the true correctness metric.

---

## Core Principles

1. **Cognitive Limits Over Raw Lines**: Control flow nesting is capped at **depth $\le 4$** (warn at 3), and conditional decision points at **branches $\le 15$**.
2. **Cognitive Tiering**: Function length thresholds reflect architectural responsibility:
   - **Standard Business Logic**: 20–60 lines (hard limit: **110 lines**)
   - **Declarative Builders & UI Layouts** (`build*`, `render*`, `View`, CLI args): Hard limit: **160 lines**
   - **Event & Route Dispatchers** (`handle*`, `dispatch*`, flat `match`): Hard limit: **200 lines**
   - **Integration & Unit Tests** (`Test*` / `#[test]`): Hard limit: **250 lines**
3. **Flat Switch / Match Exemption**: A `switch` or `match` counts as 1 decision point; individual flat arms delegating to named helpers do not increment branch complexity.
4. **Left-Aligned "Line of Sight"**: Happy path using guard clauses (`let-else` in Rust, early `if err != nil` in Go). **Strict prohibition of `else` after terminal statements** (`return`, `continue`, `break`, `panic`).
5. **Anti-Decomposition Rules for Agents**:
   - Every extracted helper must have a cohesive, domain-named responsibility.
   - Never extract artificial continuation fragments (`stepA`, `stepB`).
   - Never extract helpers that require parameter dumping ($>4$ parameters or pointers/clones to pass local state).
   - In Rust: **Never insert `.clone()` or wrap in synchronization primitives solely to resolve borrow checker conflicts during function extraction**.

---

## Repository Structure

```text
agentic-coding-guidelines/
├── README.md                 # Overview & quickstart
├── LICENSE                   # MIT License
├── go/
│   ├── README.md             # Go quick reference & CLI usage
│   ├── GUIDELINES.md         # Canonical Operational Guide (agent & human ready)
│   ├── RATIONALE.md          # Deep-dive philosophy, Miller's Law & anti-patterns
│   ├── bin/                  # Standalone verification CLI tools
│   │   ├── go-audit          # Sizing & cognitive complexity auditor
│   │   ├── go-static-analysis# Multi-linter orchestrator (gocritic, shadow, revive, dupl, govulncheck)
│   │   └── go-install-tools  # Automated linter installer into ~/.go/bin/
│   └── templates/            # Reusable project workflow templates
│       ├── Makefile.snippet  # Standard Makefile targets
│       ├── check.rb          # Pre-commit CI quality gate
│       ├── commit.rb         # Gated commit with .verified_head
│       └── bump.rb           # Version bump & install script
└── rust/
    ├── README.md             # Rust quick reference & CLI usage
    ├── GUIDELINES.md         # Canonical Operational Guide (agent & human ready)
    ├── RATIONALE.md          # Deep-dive philosophy, borrowck anti-patterns & divergences
    ├── bin/                  # Standalone verification CLI tools
    │   ├── rust-audit        # Sizing, cognitive complexity & unwrap/safety auditor
    │   ├── rust-static-analysis # Multi-linter orchestrator (clippy, audit, deny, machete, geiger)
    │   └── rust-install-tools# Automated cargo tools installer into ~/.cargo/bin/
    └── templates/            # Reusable project workflow templates
        ├── Makefile.snippet  # Standard Makefile targets
        ├── check.rb          # Pre-commit CI quality gate (Tier 1)
        ├── commit.rb         # Gated commit with .verified_head
        ├── bump.rb           # 3-Tier milestone version bump & install script
        └── install.rb        # Direct cargo install --root ~ script
```

---

## How to Use in Your Projects

### 1. In Your Global or Project Agent Prompt (`AGENTS.md` / `CLAUDE.md` / `.cursorrules`)

Add the directives to your AI prompt or system instructions:

```markdown
## Go Engineering Standards
- **Guidelines**: Strictly adhere to the architecture, cognitive complexity boundaries (depth <= 4, branches <= 15), tiered function limits, and Google Go style rules in `~/prog/standards/go/GUIDELINES.md`.
- **Rationale**: Consult `~/prog/standards/go/RATIONALE.md` for the empirical reasoning, cognitive load foundations, and anti-decomposition constraints.
- **Validation**: Enforce compliance before committing using `go-audit` (sizing & cognitive complexity) and `go-static-analysis` (deep AST, symmetries, and security review).

## Rust Engineering Standards
- **Guidelines**: For any Rust project, strictly adhere to the architecture, cognitive complexity limits, `let-else` guard idioms, and anti-clone rules defined in `~/prog/standards/rust/GUIDELINES.md`.
- **Rationale**: Consult `~/prog/standards/rust/RATIONALE.md` for the empirical reasoning, borrow-checker anti-decomposition constraints, and 3-tier milestone strategy.
- **Validation**: Enforce compliance before committing using `rust-audit` (sizing, complexity & unwrap/unsafe audit) and `rust-static-analysis` (clippy, CVEs, supply-chain & unsafe review).
```

### 2. Install the CLI Tools

Symlink the tools into your `$PATH` (e.g. `~/bin/`):

```bash
mkdir -p ~/bin

# Go Tools
ln -sf $(pwd)/go/bin/go-audit ~/bin/go-audit
ln -sf $(pwd)/go/bin/go-static-analysis ~/bin/go-static-analysis
ln -sf $(pwd)/go/bin/go-install-tools ~/bin/go-install-tools

# Rust Tools
ln -sf $(pwd)/rust/bin/rust-audit ~/bin/rust-audit
ln -sf $(pwd)/rust/bin/rust-static-analysis ~/bin/rust-static-analysis
ln -sf $(pwd)/rust/bin/rust-install-tools ~/bin/rust-install-tools
```

### 3. Run Audits in Any Repository

```bash
# Go Repositories
go-audit
go-static-analysis

# Rust Repositories
rust-audit
rust-static-analysis
```

---

## Multi-Language Roadmap

- [x] **Go**: Cognitive sizing, Google Go idioms, two-tier static review tooling.
- [x] **Rust**: Cognitive sizing, borrow-checker anti-patterns, `let-else` idioms, 3-tier milestone releases & static analysis tooling.
- [ ] **Ruby**: Cognitive complexity, rubocop orchestration, agentic refactoring rules.
- [ ] **Python**: Function tiering, ruff/mypy integration, anti-decomposition discipline.

---

## License

MIT License — see [LICENSE](LICENSE) for details.
