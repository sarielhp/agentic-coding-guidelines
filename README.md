# Agentic Coding Guidelines & Standards

[![Go Standards](https://img.shields.io/badge/Language-Go-00ADD8?style=flat&logo=go)](go/GUIDELINES.md)
[![Rust Standards](https://img.shields.io/badge/Language-Rust-dea584?style=flat&logo=rust)](rust/GUIDELINES.md)
[![Ruby Standards](https://img.shields.io/badge/Language-Ruby-CC342D?style=flat&logo=ruby)](ruby/GUIDELINES.md)
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
   - **Standard Business Logic**: 20–60 lines (hard limit: **110 lines** in Go/Rust, **80 lines** in Ruby)
   - **Declarative Builders & UI Layouts** (`build*`, `render*`, `View`, CLI args): Hard limit: **160 lines** (120 in Ruby)
   - **Event & Route Dispatchers** (`handle*`, `dispatch*`, flat `match`): Hard limit: **200 lines** (150 in Ruby)
   - **Integration & Unit Tests** (`Test*` / `#[test]` / `test_*`): Hard limit: **250 lines** (150 in Ruby)
3. **Flat Switch / Match Exemption**: A `switch` or `match` counts as 1 decision point; individual flat arms delegating to named helpers do not increment branch complexity.
4. **Left-Aligned "Line of Sight"**: Happy path using guard clauses (`let-else` in Rust, early `if err != nil` in Go, `return unless` in Ruby). **Strict prohibition of `else` after terminal statements** (`return`, `continue`, `break`, `panic`, `raise`).
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
├── go/
│   ├── README.md             # Go quick reference & CLI usage
│   ├── GUIDELINES.md         # Canonical Operational Guide (agent & human ready)
│   ├── RATIONALE.md          # Deep-dive philosophy, Miller's Law & anti-patterns
│   ├── bin/                  # Standalone verification CLI tools
│   │   ├── go-audit          # Sizing & cognitive complexity auditor
│   │   ├── go-static-analysis# Multi-linter orchestrator (gocritic, shadow, revive, dupl, govulncheck)
│   │   └── go-install-tools  # Automated linter installer into ~/.go/bin/
│   ├── test/                 # Portable tooling acceptance tests and real Go fixtures
│   └── templates/            # Reusable project workflow templates
│       ├── Makefile.snippet  # Delegates to canonical Go scripts
│       ├── AGENTS_SNIPPET.md # Exact command forms and authorization boundaries
│       ├── settings.rb      # Project artifact, check, version, and install choices
│       ├── tooling.rb       # Copied shared implementation
│       ├── build.rb         # Repository artifacts for apps, libraries, cmd layouts
│       ├── gate.rb/check.rb # One fast/full gate implementation
│       ├── lint.rb          # Fast static checks
│       ├── snapshot.rb      # Ungated local checkpoint
│       ├── commit.rb        # Gated local commit and structured verification
│       ├── bump.rb          # Full-checked patch bump and verified upstream push
│       ├── install.rb       # Declared installation and content verification
│       └── release.rb       # Commit, bump, push; installation opt-in
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
│       ├── build.rb          # tools/build: artifact only, repo-local, no tests/linters
│       ├── gate.rb           # tools/gate: Tier 1 quality gate (tools/check = symlink)
│       ├── commit.rb         # Gated commit with .verified_head
│       ├── bump.rb           # 3-Tier milestone version bump & install script
│       └── install.rb        # Direct cargo install --root ~ script
├── ruby/
│   ├── README.md             # Ruby quick reference & CLI usage
│   ├── GUIDELINES.md         # Canonical Operational Guide (agent & human ready)
│   ├── RATIONALE.md          # Deep-dive philosophy, block scoping, GC memory churn
│   ├── bin/                  # Standalone verification CLI tools
│   │   ├── ruby-audit        # AST cognitive complexity, depth & sizing auditor
│   │   ├── ruby-static-analysis # Multi-linter orchestrator (syntax, rubocop, bundle-audit, dupl)
│   │   └── ruby-install-tools# Automated gem and tooling auditor/installer
│   └── templates/            # Reusable project workflow templates
│       ├── Makefile.snippet  # Standard Makefile targets
│       ├── build.rb          # tools/build: artifact only, repo-local, no tests/linters
│       ├── gate.rb           # tools/gate: Tier 1 quality gate (tools/check = symlink)
│       ├── commit.rb         # Gated commit with .verified_head
│       ├── bump.rb           # Semver bump & tag script (trusts .verified_head)
│       ├── install.rb        # Copy/symlink bin/* into ~/bin
│       └── dot_rubocop.yml   # Balanced RuboCop configuration template
└── workflow/                 # Review-cycle CONTRACT (the engine lives in ~/prog/26/ruby/review_cycle)
    ├── README.md             # What a repository provides: tools/gate, tools/build, review_cycle.json
    └── templates/            # Project configuration templates
        ├── review_cycle.json # Standard repository contract template
        └── AGENTS_SNIPPET.md # Drop-in documentation block for AGENTS.md
```

---

## Project Onboarding Protocol (Day 1 Bootstrap)

To bring any new or existing repository under these standards in 3 deterministic steps:

### Step 1: Adopt Language Workflow Templates
Copy the standard quality gates, bumper, and guarded commit harness into your project's `tools/` directory:

For **Go**, follow [the Go onboarding guide](go/README.md#adopt-the-repository-interface):
copy build/gate/check/lint/snapshot/commit/bump/install/release under their canonical
names, plus `settings.rb` and `tooling.rb` unchanged. Adapt settings and ignore
declared build artifacts. The following existing copy procedure applies to
**Ruby and Rust**, whose workflow behavior is unchanged:

```bash
mkdir -p tools
LANG=ruby   # or rust; Go additionally needs its copied helper/settings files

# Lifecycle scripts, installed under their canonical names (no .rb extension):
for t in build gate commit bump install; do
  [ -f ~/prog/standards/$LANG/templates/$t.rb ] && cp ~/prog/standards/$LANG/templates/$t.rb tools/$t
done
chmod +x tools/*
ln -sf gate tools/check          # compatibility alias: tools/check == tools/gate

# Ruby only: lint baseline and the version pin read by RuboCop and mise/rbenv
cp ~/prog/standards/ruby/templates/dot_rubocop.yml .rubocop.yml
ruby -e 'puts RUBY_VERSION' > .ruby-version
```

### Step 2: Bootstrap the Review & Quality Contract
Run the idempotent onboarding command from the root of your project:

```bash
review-cycle --setup
```

This automatically:
- Validates environment prerequisites (`--doctor`: Ruby $\ge 3.0$, Git, `bws`, `agy-run-wild`, `audit`).
- Generates `tools/review_cycle.json` (`tools/gate`, `tools/build`, guidelines, and source targets). The auditor is `review-audit` on PATH; nothing is linked into the project.
- Checks the `tools/build` contract and, for Ruby projects, creates `.ruby-version` if missing.
- Enforces Git hygiene by appending `reviews/archive/` and `reviews/logs/` to `.gitignore`.
- Appends the standard review cycle specification block to `AGENTS.md`.

### Step 3: Repository Lifecycle

Go's canonical interface is documented in
[GUIDELINES §8](go/GUIDELINES.md#8-repository-tooling-interface): build, gate/check,
lint, snapshot, commit, bump, install, and release. `tools/commit <message>` is
local and does not push. Bump validates and pushes to a verified upstream;
installation is separate or explicitly selected with `tools/release --install`.
Fast verification cannot replace full release checking. Gates finish with a build.

The existing **Ruby/Rust** lifecycle below retains its language-specific behavior:

| Command | Lifecycle Role | Frequency | Description |
| :--- | :--- | :--- | :--- |
| **`tools/build`** | Build Contract | Called by gate, install, review-cycle | Produces or validates the artifact inside the repo. Never writes outside it, never runs tests or linters. May be trivial (a syntax check for Ruby). |
| **`tools/gate`** | Fast Quality Gate | Every edit / pre-commit | Tier 1 gate: unit tests, formatting, linter, cognitive complexity limits; runtime depends on the project. |
| **`tools/commit <message>`** | Guarded Git Commit | Multiple times daily | Runs `tools/gate`, stages changes, commits, and records `.verified_head`; consult each language template for publication behavior. |
| **`tools/bump`** | Milestone Release | Version milestones | Bumps the version, runs `tools/gate` unless `.verified_head` matches HEAD and only the version changed, tags, pushes, and runs `tools/install`. (Rust adds Tier 2/3 milestone checks.) |
| **`tools/install`** | Install | After a release | Runs `tools/build`, then copies or symlinks the artifact into `~/bin`. The only script allowed to write outside the repository. |
| **`review-cycle`** | Autonomous Remediation | Periodic / on-demand | 5-phase closed-loop engine: 6-lens audit $\to$ `bws` sandbox fix $\to$ gate verification $\to$ auto-commit. Separate program (`~/prog/26/ruby/review_cycle`); this repo defines only its contract. |

#### The `tools/build` contract

Every repository carries a `tools/build`, even when it is almost empty, so no tool ever has to guess a build command:

- It produces or validates the artifact **inside the repository** and exits non-zero on failure (`cargo build --release`, `go build ./...`, `ruby -cw` over the sources).
- Repository artifacts stay inside the repository. Compiler/module caches may be external. Installing is `tools/install`'s job, and `tools/install` calls `tools/build` first.
- It runs **no tests and no linters**. Build answers "does the artifact exist and parse"; `tools/gate` answers "is it good". A build that grows into a second gate makes the review cycle pay twice.
- Go's gate calls build once after successful checks and tests. Existing Ruby/Rust gates retain their language-specific ordering. Keep build validation defined in the build entry point.

`review-cycle --setup` warns when `tools/build` is missing and never falls back to `tools/install`.

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
- **Engine**: Execute closed-loop review and remediation using `review-cycle` (installed from `~/prog/26/ruby/review_cycle` via its `tools/install --link review-cycle`).
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
# review-cycle is installed from its own repository:
#   (cd ~/prog/26/ruby/review_cycle && tools/install --link review-cycle)
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
