# Agentic Coding Guidelines & Standards

[![Go Standards](https://img.shields.io/badge/Language-Go-00ADD8?style=flat&logo=go)](go/GUIDELINES.md)
[![Rust Standards](https://img.shields.io/badge/Language-Rust-dea584?style=flat&logo=rust)](rust/GUIDELINES.md)
[![Ruby Standards](https://img.shields.io/badge/Language-Ruby-CC342D?style=flat&logo=ruby)](ruby/GUIDELINES.md)
[![Julia Standards](https://img.shields.io/badge/Language-Julia-9558B2?style=flat&logo=julia)](julia/GUIDELINES.md)
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
├── julia/
│   ├── README.md             # Julia quick reference & CLI usage
│   ├── GUIDELINES.md         # Canonical Operational Guide (agent & human ready)
│   ├── RATIONALE.md          # Type stability, return-type, @fastmath and refactoring-safety evidence
│   ├── bin/                  # Standalone verification CLI tools
│   │   ├── julia-audit       # AST depth, cognitive complexity, sizing & trap auditor (Ruby CLI)
│   │   ├── julia-ast-metrics.jl # Metrics extractor built on Base.JuliaSyntax (no packages)
│   │   ├── julia-static-analysis # Syntax, JuliaFormatter, JET, ExplicitImports, Aqua
│   │   ├── julia-checks.jl   # Julia-side runner for the static analyzers
│   │   ├── analysis_support.rb # Required wrapper support
│   │   └── julia-install-tools # Tools-environment auditor/installer (separately authorized)
│   └── templates/            # AGENTS_SNIPPET.md and dot_JuliaFormatter.toml
├── rust/
│   ├── README.md             # Rust quick reference & CLI usage
│   ├── GUIDELINES.md         # Canonical Operational Guide (agent & human ready)
│   ├── RATIONALE.md          # Deep-dive philosophy, borrowck anti-patterns & divergences
│   ├── bin/                  # Standalone verification CLI tools
│   │   ├── rust-audit        # Sizing, cognitive complexity & unwrap/safety auditor
│   │   ├── rust-static-analysis # Multi-linter orchestrator (clippy, audit, deny, machete)
│   │   ├── analysis_support.rb # Required wrapper support
│   │   └── rust-install-tools# Automated cargo tools installer into ~/.cargo/bin/
│   └── templates/            # Reusable project workflow templates
│       ├── settings.rb      # Cargo layout, version, milestone and install settings
│       ├── tooling.rb/language.rb # Copied lifecycle and Rust implementation
│       ├── AGENTS_SNIPPET.md # Exact commands and authorization boundaries
│       ├── Makefile.snippet  # Delegates to canonical scripts
│       └── *.rb             # build/lint/test/gate/check/snapshot/commit/bump/install/release
├── ruby/
│   ├── README.md             # Ruby quick reference & CLI usage
│   ├── GUIDELINES.md         # Canonical Operational Guide (agent & human ready)
│   ├── RATIONALE.md          # Deep-dive philosophy, block scoping, GC memory churn
│   ├── bin/                  # Standalone verification CLI tools
│   │   ├── ruby-audit        # AST cognitive complexity, depth & sizing auditor
│   │   ├── ruby-static-analysis # Required syntax, RuboCop, dependency and Flay checks
│   │   ├── analysis_support.rb # Required wrapper support
│   │   └── ruby-install-tools# Automated gem and tooling auditor/installer
│   └── templates/            # Reusable project workflow templates
│       ├── settings.rb      # Ruby scope, tests, version, artifact and install settings
│       ├── tooling.rb/language.rb # Copied lifecycle and Ruby implementation
│       ├── AGENTS_SNIPPET.md # Exact commands and authorization boundaries
│       ├── Makefile.snippet  # Delegates to canonical scripts
│       ├── *.rb             # build/lint/test/gate/check/snapshot/commit/bump/install/release
│       └── dot_rubocop.yml   # Balanced RuboCop configuration template
├── test/                     # Rust/Ruby lifecycle and analyzer tests, Julia auditor tests, real language fixtures
└── workflow/                 # Review-cycle CONTRACT (the engine lives in ~/prog/26/ruby/review_cycle)
    ├── README.md             # What a repository provides: tools/gate, tools/build, review_cycle.json
    └── templates/            # Project configuration templates
        ├── review_cycle.json # Standard repository contract template
        └── AGENTS_SNIPPET.md # Drop-in documentation block for AGENTS.md
```

---

## Project Onboarding Protocol (Day 1 Bootstrap)

To bring any new or existing repository under these standards in 3 deterministic steps:

### Step 1: Adopt language workflow templates

Follow the language-specific bootstrap instructions in [Go](go/README.md), [Rust](rust/README.md), [Ruby](ruby/README.md), or [Julia](julia/README.md). Copy the entry points together with their helpers and settings; adapt the project artifact layout, checks, version source, and installation destinations. Include that language's Makefile and agent snippets. Existing projects require explicit migration; these templates do not update them automatically.

### Step 2: Bootstrap the Review & Quality Contract

After adopting the complete language tooling, create or reconcile the project contract using [workflow/templates/review_cycle.json](workflow/templates/review_cycle.json). Its repository-wide target supports different layouts and `push: false` keeps review commits local. Narrow the target and adapt the guidelines for the project. Preserve existing settings rather than overwriting an existing configuration.

For requested onboarding, run from the project root:

```bash
rtk proxy review-cycle --setup
rtk proxy review-cycle --doctor
rtk proxy tools/gate
```

Setup requires executable `tools/build` and a resolvable gate before configuring local bws profiles/tool mounts. It checks host and sandbox prerequisites, creates missing configuration with local commits by default, adds ignore entries, and refreshes the recognized agent review section. Ruby projects receive `.ruby-version` if absent. Install dependencies separately. Existing configuration and unrelated agent sections are preserved; inspect explicit `push: true` settings. Setup does not copy lifecycle helpers or grant bws trust.

Setup uses [workflow/templates/AGENTS_SNIPPET.md](workflow/templates/AGENTS_SNIPPET.md), with an embedded fallback when unavailable. Reconcile custom review sections manually when setup preserves them. See [workflow/README.md](workflow/README.md) for strict configuration validation, build ownership, differential verification, dry-run effects, publication checks, and remaining boundaries. Use `rtk proxy review-cycle --no-push` to override a push-enabled configuration.

### Step 3: Repository lifecycle

All three languages use the same separation of build, checking, local commits, publication, and explicit installation. Read the language settings and guidelines for check scope and version behavior.

| Command | Behavior |
|---|---|
| `tools/build` | Produce/validate repository artifacts; no checks or installation. |
| `tools/lint`, `tools/test` | Separate static feedback and tests. |
| `tools/gate`, `tools/check` | Canonical fast gate; add `--full` for release checks. |
| `tools/snapshot [message]` | Ungated local checkpoint, bypassing commit hooks. |
| `tools/commit [--full] <message>` | Checked local commit; structured verification records checked inputs and level. |
| `tools/bump` | Version change, full gate, commit, and verified push to the configured upstream; no installation. |
| `tools/bump --resume` | Resume an inspected interrupted release without another bump. |
| `tools/install` | Build and verify declared installation targets when installation is authorized. |
| `tools/release [--install] <message>` | Commit and publish; installation only with `--install`. |
| `review-cycle` | Separate remediation engine; uses the project's build/gate contract. |

The language lifecycle scripts stop on missing required tools and failed commands. The separate review engine checks verification and Git failures, defaults to local commits, and documents its remaining boundaries in [workflow/README.md](workflow/README.md). Bootstrap remains separate. Bumps check changed versions fully and verify remote refs. Compiler/dependency caches may be external; repository artifacts stay inside the repository. Reuse session authorization while keeping sandboxing and manual approval review enabled.

#### The `tools/build` contract

Every repository carries a `tools/build`, even when it is almost empty, so no tool ever has to guess a build command:

- It produces or validates the artifact **inside the repository** and exits non-zero on failure (`cargo build --release`, `go build ./...`, `ruby -cw` over the sources).
- Repository artifacts stay inside the repository. Compiler/module caches may be external. Installing is `tools/install`'s job, and `tools/install` calls `tools/build` first.
- It runs **no tests and no linters**. Build answers "does the artifact exist and parse"; `tools/gate` answers "is it good". A build that grows into a second gate makes the review cycle pay twice.
- Go and Rust gates call build once after successful checks and tests; Ruby checks syntax once before its analyzers and tests. Keep build validation defined in the build entry point.

`review-cycle --setup` fails when executable `tools/build` is missing and never falls back to `tools/install`.

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
- **Validation**: Enforce compliance before committing using `rust-audit` (sizing, complexity & unwrap/unsafe audit) and `rust-static-analysis` (clippy, CVEs & supply-chain review).

## Ruby Engineering Standards
- **Guidelines**: Follow `~/prog/standards/ruby/GUIDELINES.md` for method/file tiers, cognitive limits, idioms, and standalone scope.
- **Rationale**: Consult `~/prog/standards/ruby/RATIONALE.md` for block scoping, allocations, and anti-decomposition rules.
- **Validation**: Small standalone scripts use syntax and strict `ruby-audit`; projects use the fast gate and full RuboCop/dependency/Flay review before release.

## Autonomous Review & Remediation Loop
- **Engine**: Execute closed-loop review and remediation using `review-cycle` (installed from `~/prog/26/ruby/review_cycle` via its `tools/install --link review-cycle`).
- **Lenses**: Audit across the 6 specialized domain lenses (`systems`, `security`, `correctness`, `resilience`, `performance`, `cli`) via `review-audit`.
- **Sandbox Isolation**: Remediation runs inside isolated [bws](https://github.com/sarielhp/bws) sandboxes with automated git squash-merge and rollback guards.
- **Contract**: Define project gates, build commands, and file limits in `review_cycle.json` (or `tools/review_cycle.json`).
```

### 2. Install the CLI Tools

When installation is requested and allowed by your environment, symlink the tools into your `$PATH` (e.g. `~/bin/`). Keep each wrapper's support files in its standards directory:

```bash
rtk proxy mkdir -p ~/bin

# Go Tools
rtk proxy ln -sf "$PWD/go/bin/go-audit" ~/bin/go-audit
rtk proxy ln -sf "$PWD/go/bin/go-static-analysis" ~/bin/go-static-analysis
rtk proxy ln -sf "$PWD/go/bin/go-install-tools" ~/bin/go-install-tools

# Rust Tools
rtk proxy ln -sf "$PWD/rust/bin/rust-audit" ~/bin/rust-audit
rtk proxy ln -sf "$PWD/rust/bin/rust-static-analysis" ~/bin/rust-static-analysis
rtk proxy ln -sf "$PWD/rust/bin/rust-install-tools" ~/bin/rust-install-tools

# Ruby Tools
rtk proxy ln -sf "$PWD/ruby/bin/ruby-audit" ~/bin/ruby-audit
rtk proxy ln -sf "$PWD/ruby/bin/ruby-static-analysis" ~/bin/ruby-static-analysis
rtk proxy ln -sf "$PWD/ruby/bin/ruby-install-tools" ~/bin/ruby-install-tools

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
review-cycle --loop           # Run bounded review rounds (seven cycles by default)
review-cycle -p security      # Target a specific lens profile directly
```

---

## Multi-Language & Workflow Roadmap

- [x] **Autonomous Review Loop**: 5-phase closed-loop engine, 6 adversarial audit lenses, 4:2:1 model cadence, test-weakening guard, and [bws](https://github.com/sarielhp/bws) sandbox integration.
- [x] **Go**: Cognitive sizing, Google Go idioms, two-tier static review tooling.
- [x] **Rust**: Cognitive sizing, borrow-checker anti-patterns, `let-else` idioms, 3-tier milestone releases & static analysis tooling.
- [x] **Ruby**: Cognitive complexity, RuboCop/Flay review, scoped script rules, verified lifecycle tooling.
- [ ] **Python**: Function tiering, ruff/mypy integration, anti-decomposition discipline.

---

## License

MIT License — see [LICENSE](LICENSE) for details.
