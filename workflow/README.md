# Autonomous Review & Closed-Loop Remediation Workflow

[![Workflow Guidelines](https://img.shields.io/badge/Workflow-Guidelines-00ADD8?style=flat)](GUIDELINES.md)
[![Workflow Rationale](https://img.shields.io/badge/Workflow-Rationale-8A2BE2?style=flat)](RATIONALE.md)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](../LICENSE)

The `workflow` subsystem defines the authoritative architecture, tooling, and closed-loop engine for **autonomous adversarial code review, planning, sandbox remediation, quality gate verification, and targeted re-verification**.

It is completely **language-agnostic** and provides native audit profiles, test detection, and AST complexity gate integrations for **Go**, **Rust**, and **Ruby**.

---

## Architecture: The 5-Phase Closed-Loop Verification Pipeline

Every review cycle executes an autonomous, transactionally guarded workflow with a Monotonic Progressive Ratchet:

```text
                  ┌──────────────────────────────────────────────┐
                  │ Phase 1: Deep Adversarial Audit              │
                  │   systems / performance  ──> Codex (Tier 1)  │
                  │   security / correctness ──> Claude (Tier 1) │
                  └───────────────────────┬──────────────────────┘
                                          │
                             Defects > 0? │ (0 defects -> mark lens CLEAN & advance)
                                          ▼
                  ┌──────────────────────────────────────────────┐
                  │ Phase 2: Rapid Sandbox Remediation           │
                  │ (bws gw -b fix-branch -- agy-run-wild)       │
                  │  - Gemini Flash: fast (15-30s) bounded edits │
                  │  - Enforce regression test + no atrophy      │
                  │  - Round 2+: laser-focused cognitive relief  │
                  │  - Auto-squash-merge to branch               │
                  └───────────────────────┬──────────────────────┘
                                          │
                                          ▼
                  ┌──────────────────────────────────────────────┐
                  │ Phase 3: Deterministic Quality Gate          │
                  │ (tools/gate, check.rb, go-audit, test -race) │
                  └───────────────────────┬──────────────────────┘
                                          │
                             Gate Passed? │ (Failed -> Restore latest ratchet point)
                                          ▼
                  ┌──────────────────────────────────────────────┐
                  │ Phase 4: Targeted Re-Verification Pass       │
                  │ (tools/audit --verify-remediation)           │
                  │  - Re-invoke SAME auditor (Codex/Claude)     │
                  │  - Cumulative diff verification: base..HEAD  │
                  │  - Evaluate 0 regressions & severity ratchet │
                  └───────────────────────┬──────────────────────┘
                                          │
            ┌─────────────────────────────┴─────────────────────────────┐
            │                                                           │
   Verified Clean (0 defects)                              Partial / Failed / Regressed
            │                                                           │
            ▼                                                           ▼
┌──────────────────────────────────────┐            ┌──────────────────────────────────────┐
│ Phase 5: Complete & Advance          │            │ Monotonic Progressive Ratchet Check  │
│  - Mark lens CLEAN, commit & archive │            │  - Lexicographical progress check    │
│  - Rotate to next profile in cadence │            │    (highest open severity reduced)   │
└──────────────────────────────────────┘            │  - Regressed / No progress?          │
                                                    │    Reset to latest ratchet point     │
                                                    │  - Attempts remaining (< max)?       │
                                                    │    Re-enter P2 with laser prompt     │
                                                    │  - Attempts exhausted (>= max)?      │
                                                    │    * If ratchet > base: commit &     │
                                                    │      archive partial_remediation     │
                                                    │    * If ratchet == base: rollback    │
                                                    │      workspace & mark BLOCKED        │
                                                    └──────────────────────────────────────┘
```

For the theoretical and mathematical foundations behind closed-loop convergence, the Monotonic Progressive Ratchet, and anti-oscillation, see [`RATIONALE.md`](RATIONALE.md).

---

## The 6 Multi-Lens Audit Profiles

Evaluation is strictly partitioned across 6 orthogonal domain lenses:

| Profile | Domain Pillar | Primary Focus Area | Backend Affinity |
| :--- | :--- | :--- | :--- |
| **`systems`** | Systems & Concurrency | Deadlocks, race conditions, atomic writes, memory safety, async task cancellation leaks | Codex (`gpt-5.6-sol`) |
| **`security`** | Security & Attack Surface | Path traversal, shell/macro injection, ReDoS, credential leaks, unbounded network buffers | Claude (`sonnet` / `opus`) |
| **`correctness`** | Domain Specifications | Specification conformance, format idempotency, lossy field conversions, zero values | Claude (`sonnet` / `opus`) |
| **`resilience`** | Resilience & Observability | Network timeouts, HTTP 429/503 retry backoff with jitter, silent error swallowing (`.ok()`, `_ =`) | Claude (`sonnet` / `opus`) |
| **`performance`** | Complexity & Allocations | $O(N^2)$ algorithmic comparisons, excessive heap allocations in hot loops, unbuffered I/O | Codex (`gpt-5.6-sol`) |
| **`cli`** | Ergonomics & Help System | One canonical interface, anti-alias-bloat, concise `-h` ($\le 20$ lines), exit code hygiene | Claude (`sonnet`) |

---

## Asymmetric Model Architecture

We pair high-reasoning models with fast, tool-integrated sandbox agents:
1. **Auditing & Re-Verification (Discovery & Proof)**: **Tier 1 Codex & Claude**. Audit and verification require broad context analysis and deep reasoning. Profile affinity routes `systems`/`performance` to Codex and `security`/`correctness` to Claude.
2. **Remediation (Implementation)**: **Gemini Flash (`agy-run-wild`)** inside [`bws gw`](https://github.com/sarielhp/bws). Once a defect is localized, Gemini Flash executes surgical edits and updates unit tests in 15–30 seconds.
3. **Oracle (Deterministic Ground Truth)**: Compilers, unit test suites, and AST complexity linters (`tools/check.rb`, `go-audit`, `rust-audit`, `ruby-audit`).

---

## Multi-Language Support: Go, Rust & Ruby

The engine automatically detects the project language and enforces corresponding repository standards:

| Language | Manifest | Authoritative Standards | Gate Tools | Test Conventions |
| :--- | :--- | :--- | :--- | :--- |
| **Go** | `go.mod` | [`standards/go/GUIDELINES.md`](../go/GUIDELINES.md) | `go-audit`, `go vet`, `go test -race` | `*_test.go` |
| **Rust** | `Cargo.toml` | [`standards/rust/GUIDELINES.md`](../rust/GUIDELINES.md) | `rust-audit`, `clippy`, `cargo test` | `tests/**/*.rs`, `*_test.rs`, inline `#[cfg(test)]` |
| **Ruby** | `Gemfile` / `lib/` | [`standards/ruby/GUIDELINES.md`](../ruby/GUIDELINES.md) | `ruby-audit`, `rubocop`, `rake test` | `test/**/test_*.rb`, `spec/**/*_spec.rb`, inline `def test_` |

---

## Directory Structure

```text
~/prog/standards/workflow/  (also symlinked as ~/prog/standards/review-cycle/)
├── README.md               # Overview & quickstart guide
├── GUIDELINES.md           # Operational rules, invariants & lifecycle contracts
├── RATIONALE.md            # Empirical rationale, anti-oscillation, & model pairing
├── bin/
│   ├── review_cycle        # 5-phase closed-loop orchestration engine
│   └── audit               # Multi-lens adversarial code auditor & verifier
└── templates/
    ├── review_cycle.json   # Standard repository configuration contract
    └── AGENTS_SNIPPET.md   # Documentation snippet for project AGENTS.md
```

---

## How to Adopt in Any Project

### 1. Link Tools to Project `tools/`

In your repository:

```bash
mkdir -p tools
ln -sf ~/prog/standards/workflow/bin/review_cycle tools/review_cycle
ln -sf ~/prog/standards/workflow/bin/audit tools/audit
```

### 2. Onboard Automatically via `--setup`

Run the onboard command in your repository:

```bash
./tools/review_cycle --setup
```

This verifies prerequisites, generates `tools/review_cycle.json`, adds artifact directories to `.gitignore`, and appends the agent documentation snippet to `AGENTS.md`.

---

## CLI Usage Quick Reference

```bash
# Run a single review and remediation cycle (profile affinity)
tools/review_cycle

# Run continuously until all 6 profiles pass clean without defects
tools/review_cycle --loop

# Inspect current rotation state, cycle count, and history
tools/review_cycle --status

# Dry-run: audit and generate review report without launching sandbox
tools/review_cycle --dry-run

# Run audit standalone on a specific profile or file
tools/audit -p security src/

# Run targeted re-verification on a patch against a previous report
git diff HEAD~1..HEAD | tools/audit -p security -V reviews/001_security.md
```

---

## Prerequisites & Ecosystem Dependencies

- **`bws`**: [Bubblewrap Git Worktree Sandbox](https://github.com/sarielhp/bws) (`bws gw`) creates an ephemeral, air-gapped sandbox clone with host `$HOME` protection and 1-key merge triage.
- **`agy-run-wild`**: Autonomous coding agent runner dispatched inside the `bws` sandbox.
- **`git`**: Version control and worktree management.
- **Ruby >= 3.0**: Runtime for orchestrator scripts.
