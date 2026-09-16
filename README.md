# Agentic Coding Guidelines & Standards

[![Go Standards](https://img.shields.io/badge/Language-Go-00ADD8?style=flat&logo=go)](go/GUIDELINES.md)
[![Rust Standards](https://img.shields.io/badge/Language-Rust-dea584?style=flat&logo=rust)](rust/GUIDELINES.md)
[![Review Cycle](https://img.shields.io/badge/Workflow-Review%20Cycle-8A2BE2?style=flat)](workflow/README.md)
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
6. **Closed-Loop Adversarial Review**: Continuous automated code quality audits across 6 orthogonal domain lenses (`systems`, `security`, `correctness`, `resilience`, `performance`, `cli`), paired with transactionally safe remediation in isolated Git sandboxes ([`bws`](https://github.com/sarielhp/bws)) and a 4:2:1 model tier rotation.

---

## Repository Structure

```text
agentic-coding-guidelines/
├── README.md                 # Overview & quickstart
├── LICENSE                   # MIT License
├── review-cycle -> workflow  # Canonical symlink for workflow engine
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
├── rust/
│   ├── README.md             # Rust quick reference & CLI usage
│   ├── GUIDELINES.md         # Canonical Operational Guide (agent & human ready)
│   ├── RATIONALE.md          # Deep-dive philosophy, borrowck anti-patterns & divergences
│   ├── bin/                  # Standalone verification CLI tools
│   │   ├── rust-audit        # Sizing, cognitive complexity & unwrap/safety auditor
│   │   ├── rust-static-analysis # Multi-linter orchestrator (clippy, audit, deny, machete, geiger)
│   │   └── rust-install-tools# Automated cargo tools installer into ~/.cargo/bin/
│   └── templates/            # Reusable project workflow templates
│       ├── Makefile.snippet  # Standard Makefile targets
│       ├── check.rb          # Pre-commit CI quality gate (Tier 1)
│       ├── commit.rb         # Gated commit with .verified_head
│       ├── bump.rb           # 3-Tier milestone version bump & install script
│       └── install.rb        # Direct cargo install --root ~ script
└── workflow/                 # Autonomous Review & Remediation Loop (review-cycle)
    ├── README.md             # Architecture, 5-phase loop & 4:2:1 cadence spec
    ├── bin/                  # Autonomous orchestration binaries
    │   ├── review_cycle      # 5-phase closed-loop orchestration engine
    │   └── audit             # Multi-lens adversarial code auditor (6 domain profiles)
    └── templates/            # Project configuration templates
        ├── review_cycle.json # Standard repository contract template
        └── AGENTS_SNIPPET.md # Drop-in documentation block for AGENTS.md
```

---

## Project Onboarding Protocol (Day 1 Bootstrap)

To bring any new or existing repository under these standards in 3 deterministic steps:

### Step 1: Adopt Language Workflow Templates
Copy the standard quality gates, bumper, and guarded commit harness into your project's `tools/` directory:

```bash
mkdir -p tools

# For Rust Projects:
cp ~/prog/standards/rust/templates/{check.rb,commit.rb,bump.rb,install.rb} tools/
chmod +x tools/*

# For Go Projects:
cp ~/prog/standards/go/templates/{check.rb,commit.rb,bump.rb} tools/
chmod +x tools/*
```

### Step 2: Bootstrap the Review & Quality Contract
Run the idempotent onboarding command from the root of your project:

```bash
review-cycle --setup
```

This automatically:
- Validates environment prerequisites (`--doctor`: Ruby $\ge 3.0$, Git, `bws`, `agy-run-wild`, `audit`).
- Generates `tools/review_cycle.json` (auto-detecting `tools/gate`, build commands, guidelines, and source targets).
- Provisions a local `tools/audit` symlink pointing to the canonical multi-lens auditor.
- Enforces Git hygiene by appending `reviews/archive/` and `reviews/logs/` to `.gitignore`.
- Appends the standard review cycle specification block to `AGENTS.md`.

### Step 3: The 4-Command Everyday Lifecycle
Once onboarded, maintainers and AI agents operate through 4 canonical commands:

| Command | Lifecycle Role | Frequency | Description |
| :--- | :--- | :--- | :--- |
| **`tools/gate`** | Fast Quality Gate | Every edit / pre-commit | Sub-second Tier 1 gate: unit tests, formatting, linter, cognitive complexity limits. |
| **`tools/commit -m "..."`** | Guarded Git Commit | Multiple times daily | Runs `tools/gate`, verifies `.verified_head`, stages changes, commits, and pushes to remote. |
| **`tools/bump`** | Milestone Release | Version milestones | 3-tier milestone guard (auto-triggers Tier 2 benchmarks and Tier 3 compiler tests), bumps versions, updates changelog, and pushes git tags. |
| **`review-cycle`** | Autonomous Remediation | Periodic / on-demand | 5-phase closed-loop engine: 6-lens audit $\to$ `bws` sandbox fix $\to$ gate verification $\to$ auto-commit. |

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

## Autonomous Review & Remediation Loop
- **Engine**: Execute closed-loop review and remediation using `review-cycle` (or `./tools/review_cycle`).
- **Lenses**: Audit across the 6 specialized domain lenses (`systems`, `security`, `correctness`, `resilience`, `performance`, `cli`) via `audit`.
- **Sandbox Isolation**: Remediation runs inside isolated [bws](https://github.com/sarielhp/bws) sandboxes with automated git squash-merge and rollback guards.
- **Contract**: Define project gates, build commands, and file limits in `review_cycle.json` (or `tools/review_cycle.json`).
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

# Autonomous Review Workflow
ln -sf $(pwd)/workflow/bin/review_cycle ~/bin/review-cycle
```

### 3. Run Audits & Workflows in Any Repository

```bash
# Go Repositories
go-audit
go-static-analysis

# Rust Repositories
rust-audit
rust-static-analysis

# Autonomous Review & Remediation Loop
review-cycle --doctor         # Validate runtime dependencies (Ruby, git, bws, agy-run-wild, audit)
review-cycle                  # Run a single review and remediation cycle
review-cycle --loop           # Continuously audit and heal until all profiles pass cleanly
review-cycle -p security      # Target a specific lens profile directly
```

---

## Multi-Language & Workflow Roadmap

- [x] **Autonomous Review Loop**: 5-phase closed-loop engine, 6 adversarial audit lenses, 4:2:1 model cadence, test-weakening guard, and [bws](https://github.com/sarielhp/bws) sandbox integration.
- [x] **Go**: Cognitive sizing, Google Go idioms, two-tier static review tooling.
- [x] **Rust**: Cognitive sizing, borrow-checker anti-patterns, `let-else` idioms, 3-tier milestone releases & static analysis tooling.
- [ ] **Ruby**: Cognitive complexity, rubocop orchestration, agentic refactoring rules.
- [ ] **Python**: Function tiering, ruff/mypy integration, anti-decomposition discipline.

---

## License

MIT License — see [LICENSE](LICENSE) for details.
