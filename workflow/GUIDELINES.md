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

## 5. Monotonic Progressive Ratchet & Bounded Circuit Breakers

To prevent infinite oscillation, subjective drift, and destructive all-or-nothing rollbacks:

1. **Hold the Lens**: When Lens $L$ detects defects, it remains active. The engine does **not** advance to Lens $L+1$ until Lens $L$ is verified clean or settled at a verified partial ratchet.
2. **Cumulative Targeted Verification**: Re-verification does not re-scan the entire codebase open-endedly. It evaluates the cumulative diff (`base_sha..HEAD`) strictly:
   - *Fix Conformance*: Did the patch eliminate the reported defects?
   - *Regression Freedom*: Did the patch introduce any new Critical or Major bugs in affected paths?
3. **The Monotonic Progressive Ratchet**:
   - **No Discarding of Verified Improvements**: If an attempt resolves $K$ out of $N$ findings with zero regressions and passes the quality gate, that progress is monotonically ratcheted forward (`last_ratchet_sha = HEAD`).
   - **Lexicographical Severity Invariant**: Progress is measured lexicographically: $(\Delta N_{\text{Crit}}, \Delta N_{\text{Maj}}, \Delta N_{\text{Mod}})$. Progress must reduce open defects on the **highest active severity tier**. Resolving lower-tier or stylistic issues while failing to address open Critical defects does not qualify as progress.
   - **Cognitive Relief / Laser-Focused Prompts (Round 2+)**: Subsequent remediation attempts are relieved of the cognitive burden of the full original report. The remediation prompt explicitly states:
     - Already resolved defects (treated as non-interference invariants; do NOT touch or regress).
     - Target remaining unresolved defects with explicit priority directives for the highest open tier.
   - **Safe Ratchet Point Fallback**: If an attempt introduces regressions or fails the quality gate, workspace is rolled back to `last_ratchet_sha` (never to `base_sha`), preserving earlier verified gains.
   - **Bounded Attempts & Partial Remediation Preservation**: Bounded by default to **3 attempts per cycle** (configurable via `--max-attempts N`). If attempts are exhausted and `last_ratchet_sha != base_sha`, the cycle commits and archives the progress as `partial_remediation`, logs the remaining issues for subsequent cycles, and advances without discarding work. Rollback to `base_sha` and `blocked` status occurs only if zero progress was ever achieved across all attempts.

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
