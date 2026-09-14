# Agentic Coding Guidelines & Standards

[![Go Standards](https://img.shields.io/badge/Language-Go-00ADD8?style=flat&logo=go)](go/GUIDELINES.md)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

Architectural guidelines, cognitive complexity boundaries, and automated quality gates designed specifically for **AI pair programming and autonomous coding agents** (Claude, Gemini, Cursor, Copilot, ChatGPT).

---

## The Problem: The AI Refactoring Trap

When you instruct an autonomous AI coding agent using traditional rules like *"keep functions under 80 lines"*, it optimizes blindly for the line metric rather than software design. 

This causes well-known pathological behaviors:
- **Artificial Continuation Slicing**: An agent chops a coherent 100-line linear algorithm across the middle into meaningless fragments like `processPart1()` and `processPart2()`.
- **Parameter Dumping**: The agent extracts helper functions that take 5–7 local variable pointers just to pass mutable state across an artificial boundary.
- **Context Fragmentation**: Linear logic is scattered across disparate scopes, increasing mental stack depth and degrading the agent's ability to reason about edge cases.

Raw line counts are a crude proxy for code clarity. **Cognitive complexity** (nesting depth, branch density, and mental state tracking) is the true correctness metric.

---

## Core Principles

1. **Cognitive Limits Over Raw Lines**: Control flow nesting is capped at **depth $\le 4$** (warn at 3), and conditional decision points at **branches $\le 15$**.
2. **Cognitive Tiering**: Function length thresholds reflect architectural responsibility:
   - **Standard Business Logic**: 20–60 lines (hard limit: **110 lines**)
   - **Declarative Builders & UI Layouts** (`build*`, `render*`, `View`): Hard limit: **160 lines**
   - **Event & Key Dispatchers** (`handle*`, `dispatch*`): Hard limit: **200 lines**
   - **Table-Driven Tests** (`Test*` slices): Hard limit: **250 lines**
3. **Flat Switch Exemption**: A `switch` counts as 1 decision point; individual flat `case` branches delegating to named helpers do not increment branch complexity.
4. **Google Go "Line of Sight"**: Left-aligned happy path using guard clauses. **Strict prohibition of `else` after terminal statements** (`return`, `continue`, `break`, `panic`).
5. **Anti-Decomposition Rules for Agents**:
   - Every extracted helper must have a cohesive, domain-named responsibility.
   - Never extract artificial continuation fragments (`stepA`, `stepB`).
   - Never extract helpers that require parameter dumping ($>4$ parameters or pointers to local variables).

---

## Repository Structure

```text
agentic-coding-guidelines/
├── README.md               # Overview & quickstart
├── LICENSE                 # MIT License
└── go/
    ├── README.md           # Go quick reference & CLI usage
    ├── GUIDELINES.md       # Canonical Operational Guide (agent & human ready)
    ├── RATIONALE.md        # Deep-dive philosophy, Miller's Law & anti-patterns
    ├── bin/                # Standalone verification CLI tools
    │   ├── go-audit        # Sizing & cognitive complexity auditor
    │   ├── go-static-analysis # Multi-linter orchestrator (gocritic, shadow, revive, dupl, govulncheck)
    │   └── go-install-tools# Automated linter installer into ~/.go/bin/
    └── templates/          # Reusable project workflow templates
        ├── Makefile.snippet# Standard Makefile targets
        ├── check.rb        # Pre-commit CI quality gate
        ├── commit.rb       # Gated commit with .verified_head
        └── bump.rb         # Version bump & install script
```

---

## How to Use in Your Projects

### 1. In Your Global or Project Agent Prompt (`AGENTS.md` / `CLAUDE.md` / `.cursorrules`)

Add the following directive to your AI prompt or system instructions:

```markdown
## Go Engineering Standards
- **Guidelines**: Strictly adhere to the architecture, cognitive complexity boundaries (depth <= 4, branches <= 15), tiered function limits, and Google Go style rules in `~/prog/standards/go/GUIDELINES.md`.
- **Rationale**: Consult `~/prog/standards/go/RATIONALE.md` for the empirical reasoning, cognitive load foundations, and anti-decomposition constraints.
- **Validation**: Enforce compliance before committing using `go-audit` (sizing & cognitive complexity) and `go-static-analysis` (deep AST, symmetries, and security review).
```

### 2. Install the CLI Tools

Symlink the tools into your `$PATH` (e.g. `~/bin/`):

```bash
mkdir -p ~/bin
ln -sf $(pwd)/go/bin/go-audit ~/bin/go-audit
ln -sf $(pwd)/go/bin/go-static-analysis ~/bin/go-static-analysis
ln -sf $(pwd)/go/bin/go-install-tools ~/bin/go-install-tools
```

### 3. Run Audits in Any Go Repository

```bash
# Verify cognitive complexity, nesting depth, and function sizing
go-audit

# Run deep multi-tool static analysis (gocritic, shadow, revive, dupl, govulncheck)
go-static-analysis
```

---

## Multi-Language Roadmap

- [x] **Go**: Cognitive sizing, Google Go idioms, two-tier static review tooling.
- [ ] **Ruby**: Cognitive complexity, rubocop orchestration, agentic refactoring rules.
- [ ] **Python**: Function tiering, ruff/mypy integration, anti-decomposition discipline.

---

## License

MIT License — see [LICENSE](LICENSE) for details.
