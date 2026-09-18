# Autonomous Review Cycle & Remediation Guidelines

## 1. Overview & Closed-Loop Philosophy

The `workflow` subsystem defines the authoritative guidelines for continuous, automated code review, sandbox remediation, and verification across **Go**, **Rust**, and **Ruby** projects.

The core objective is **closed-loop verification and defect convergence**. Unlike open-loop linters or conversational review bots that provide advisory comments, `review_cycle` operates as an autonomous, transactionally guarded remediation engine that holds code to rigorous domain standards.

---

## 2. The 5-Phase Closed-Loop Lifecycle

Every review cycle executes a deterministic 5-phase pipeline:

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
                  │  - Auto-squash-merge to branch               │
                  └───────────────────────┬──────────────────────┘
                                          │
                                          ▼
                  ┌──────────────────────────────────────────────┐
                  │ Phase 3: Deterministic Quality Gate          │
                  │ (tools/gate, check.rb, go-audit, test -race) │
                  └───────────────────────┬──────────────────────┘
                                          │
                             Gate Passed? │ (Failed -> Stash branch, Rollback & Halt)
                                          ▼
                  ┌──────────────────────────────────────────────┐
                  │ Phase 4: Targeted Re-Verification Pass       │
                  │ (tools/audit --verify-remediation)           │
                  │  - Re-invoke SAME auditor (Codex/Claude)     │
                  │  - Bounded verification on patch vs findings │
                  └───────────────────────┬──────────────────────┘
                                          │
                     Verified Clean? ─────┼────── Defect Remains / Regressed?
                            │             │               │
                            │             ▼               ▼
                            │      Attempt < 2?     Attempt == 2?
                            │             │               │
                            │       (Re-enter P2)   (Stash branch, Rollback & Block)
                            ▼             │               │
                  ┌───────────────────────┴───────────────┴──────┐
                  │ Phase 5: State Update & Clean Advance        │
                  │  - If clean: mark lens CLEAN, rotate to next │
                  │  - If blocked: mark lens BLOCKED, halt loop  │
                  │  - Discard empty commits if false-positive   │
                  └──────────────────────────────────────────────┘
```

---

## 3. The 6 Multi-Lens Audit Profiles

Evaluation is strictly partitioned into 6 orthogonal domain lenses tailored for systems programming:

| Profile | Domain Pillar | Primary Focus Area | Backend Affinity |
| :--- | :--- | :--- | :--- |
| **`systems`** | Systems & Concurrency | Deadlocks, race conditions, atomic writes, memory safety, async task cancellation leaks | Codex (`gpt-5.6-sol`) |
| **`security`** | Security & Attack Surface | Path traversal, shell/macro injection, ReDoS, credential leaks, unbounded network buffers | Claude (`sonnet` / `opus`) |
| **`correctness`** | Domain Specifications | Specification conformance, format idempotency, lossy field conversions, zero values | Claude (`sonnet` / `opus`) |
| **`resilience`** | Resilience & Observability | Network timeouts, HTTP 429/503 retry backoff with jitter, silent error swallowing (`.ok()`, `_ =`) | Claude (`sonnet` / `opus`) |
| **`performance`** | Complexity & Allocations | $O(N^2)$ algorithmic comparisons, excessive heap allocations in hot loops, unbuffered I/O | Codex (`gpt-5.6-sol`) |
| **`cli`** | Ergonomics & Help System | One canonical interface, anti-alias-bloat, concise `-h` ($\le 20$ lines), exit code hygiene | Claude (`sonnet`) |

---

## 4. Asymmetric Model Architecture

To maximize verification accuracy while maintaining speed and token efficiency:
* **Auditor & Re-Verifier (Discovery & Proof)**: **Tier 1 High-Reasoning Models (Codex / Claude)**.
  - Audit and verification require deep architectural context and broad invariant analysis.
  - Profile affinity directs Codex to concurrency/systems and Claude to security/correctness.
* **Remediator (Implementation & Refactoring)**: **Gemini Flash (`agy-run-wild`)** inside [`bws gw`](https://github.com/sarielhp/bws).
  - Implementation is a bounded task: once the auditor pinpoints the line, root cause, and remediation pattern, Gemini Flash executes surgical edits in 15–30 seconds.
  - Native integration with PTY streaming and local workspace tools ensures zero toolchain friction.
* **Oracle (Non-Negotiable Invariant Filter)**: Local deterministic compilers and AST linters (`tools/check.rb`, `go-audit`, `rust-audit`, `ruby-audit`).

---

## 5. Bounded Verification & Circuit Breakers

To prevent infinite oscillation and subjective drift:

1. **Hold the Lens**: When Lens $L$ detects defects, it remains active. The engine does **not** advance to Lens $L+1$ until Lens $L$ is verified clean.
2. **Targeted Verification (Anti-Oscillation)**: Re-verification does not re-scan the entire codebase open-endedly. It evaluates *strictly*:
   - Did the patch resolve the specific reported defects?
   - Did the patch introduce any new severity-1 regressions under that specific lens?
3. **2-Attempt Circuit Breaker**: Remediation is bounded to **maximum 2 attempts per lens**.
   - Attempt 1: Fix reported findings.
   - Attempt 2: If verification fails, feed the auditor's specific verification failure back into the remediation prompt.
   - If Attempt 2 fails: Automatically stash the failed branch (`reviews/failed_<num>_<profile>`), execute `git reset --hard` to base SHA, mark the profile as `blocked`, and halt.

---

## 6. Test Anchoring & Mandatory Evidence Rules

1. **Ban on "Prose Triage"**: An agent may not dismiss reported critical defects in markdown while modifying code without proof.
   - If an issue is an invalid false positive: The agent must document the technical justification in the plan and modify **zero code and zero tests**. The cycle records `outcome: 'false_positive_triage'` and makes **no git commit**.
   - If code is modified: Automated regression tests are **strictly mandatory**.
2. **Polyglot Test Discovery**:
   - **Go**: Modified `*_test.go` files.
   - **Rust**: Modified `tests/**/*.rs`, `*_test.rs`, `src/tests.rs`, **OR inline `#[cfg(test)]` / `#[test]` blocks** in `src/`.
   - **Ruby**: Modified `test/**/test_*.rb`, `spec/**/*_spec.rb`, **OR inline `def test_` / `it "..."` blocks**.
3. **Mandatory Test-Weakening & Assertion Atrophy Guard**:
   Cycles are immediately aborted and rolled back if the remediation introduces test skips (`t.Skip()`, `#[ignore]`, `skip`, `xit`) or deletes more than 2 assertions without adding at least half as many replacements.

---

## 7. Multi-Language Parity: Go, Rust & Ruby

The engine automatically discovers language context via repository manifests and injects authoritative standards:
* **Go** (`go.mod`): Enforces [`~/prog/standards/go/GUIDELINES.md`](../go/GUIDELINES.md) and `go-audit` (nesting $\le 4$, branches $\le 15$, standard functions $\le 110$ lines).
* **Rust** (`Cargo.toml`): Enforces [`~/prog/standards/rust/GUIDELINES.md`](../rust/GUIDELINES.md) and `rust-audit` (nesting $\le 4$, branches $\le 15$, functions $\le 80$ lines).
* **Ruby** (`Gemfile` / `lib/`): Enforces [`~/prog/standards/ruby/GUIDELINES.md`](../ruby/GUIDELINES.md) and `ruby-audit` (nesting $\le 4$, branches $\le 15$, methods $\le 80$ lines).
