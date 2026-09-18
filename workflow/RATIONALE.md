# Autonomous Review Cycle & Remediation RATIONALE

## 1. The Fallacy of the "Open-Ended Re-Audit"

A natural intuition in automated code review is:
> *"If an audit found critical issues, fix them, and then repeat the exact same review until critical issues are 0."*

Empirically, in multi-agent LLM systems, **unconstrained loops of this form almost never converge to 0**. Instead, they trigger three pathological failure modes:

### A. Subjective Severity Inflation (The "Nothing is Clean" Bias)
LLMs generate critiques probabilistically. When prompted as a *"Principal Systems Auditor tasked with finding critical flaws"*, an LLM is primed to return findings. Once obvious bugs are eliminated, the model does not reliably return `"NO CRITICAL DEFECTS FOUND"`. Under non-zero temperature, it lowers its internal threshold, elevating hypothetical race conditions on single-threaded startup paths or harmless style choices into `[SEVERITY]: Critical`.

### B. Architectural Ping-Pong
Remediation introduces safeguards to satisfy Review $N$ (e.g. adding a mutex, extracting a helper, or adding defensive bounds checks). In Review $N+1$, the auditor evaluates the newly modified code and complains about the mitigation itself:
* *Pass 1:* "Potential data race on map read. [Critical]" $\rightarrow$ Agent adds `sync.RWMutex`.
* *Pass 2:* "Lock contention overhead and lock inversion risk. [Critical]" $\rightarrow$ Agent refactors to channels.
* *Pass 3:* "Channel buffer deadlock hazard on cancellation. [Critical]" $\rightarrow$ Agent refactors back to mutex.

The loop becomes an endless cycle of self-contradiction.

### C. Whack-a-Mole (Saliency Shift)
An LLM attends to what is most salient in its context window. In Pass 1, function $A$ catches its attention. Once $A$ is fixed, function $B$—which was present all along but less salient—becomes the new top target. Repeating the open-ended audit marches down an endless tail of diminishing returns, bloating code and violating repository cognitive complexity ceilings.

---

## 2. Why Targeted Bounded Verification Converges

To achieve closed-loop correctness without oscillation, the verification phase must be **mathematically and logically constrained**:

1. **Evaluation Bounded to Findings & Patch**:
   [`tools/audit --verify-remediation`](bin/audit) does not ask *"Find any issues in this repository"*. It asks strictly:
   - *Fix Conformance*: Did the patch eliminate Finding 1 and Finding 2?
   - *Regression Freedom*: Did the patch introduce new Critical or Major bugs in the affected code?
2. **Eliminating Discursive Drift**:
   By forbidding open-ended exploration of untouched files during verification, the auditor cannot shift attention to unrelated modules.
3. **The 2-Attempt Circuit Breaker**:
   If an agent cannot resolve a defect within 2 attempts, the problem is usually an architectural ambiguity or an unviable fix. Continuing autonomously burns tokens and risks code degradation. Stashing the branch and halting for human review is the only sound engineering outcome.

---

## 3. Why Asymmetric Model Pairing Wins

Why pair **Tier 1 Codex / Claude** for auditing with **Gemini Flash (`agy-run-wild`)** for remediation?

### A. Cognitive Asymmetry: Discovery vs. Implementation
* **Auditing (Discovery)** is unguided, open-ended search across dozens of files. Pinpointing subtle concurrency races, TOCTOU vulnerabilities, or domain specification flaws requires deep reasoning and expansive context windows (Tier 1 Codex and Claude).
* **Remediation (Implementation)** is a bounded task. The auditor has already localized the file, line number, invariant violation, and recommended snippet. Writing the localized fix and writing a test is a bounded task where Gemini Flash excels.

### B. Execution Latency and Sandboxing
* Sandbox remediation (`bws gw`) requires an interactive loop: editing files, running local compilers, checking linter output, and committing.
* Gemini Flash (`agy-run-wild`) executes this entire multi-turn tool loop in **15–30 seconds**.
* Heavy reasoning models dispatched interactively take 2–4 minutes per cycle, increasing wall-clock runtime by 5–10× without improving the quality of a 20-line bug fix.

### C. The Deterministic Safety Net
You do not need an expensive model to write the fix because the fix is immediately filtered through **deterministic compilers and AST complexity linters** (`tools/check.rb`, `go-audit`, `rust-audit`, `ruby-audit`). If Flash generates convoluted code or breaks complexity limits, the gate rejects it instantly.

---

## 4. The Fallacy of "Prose Triage"

In early iterations of review workflows, agents were permitted to dismiss findings by documenting:
> *"Finding 1 is a false positive because our architecture handles this elsewhere."*

This creates a severe vulnerability:
1. The auditor flags a real bug.
2. The remediation agent, seeking the path of least resistance to pass the prompt, drafts a plausible-sounding markdown excuse in `plan.md`.
3. The runner accepts the plan, makes an empty commit, and records `remediated`.

**The Invariant:**
If a defect is real, **it must be proven with an automated regression test**. If a defect is genuinely an invalid false positive, the agent may dismiss it, but the cycle records `outcome: 'false_positive_triage'` and **creates zero git commits**. A review cycle must never pollute repository history with empty "triage" commits.

---

## 5. Polyglot Test Mechanics

A major flaw in naive review engines is enforcing file-name heuristics that ignore language-specific testing idioms:

* **Rust Inline Tests (`#[cfg(test)]`)**: In idiomatic Rust, unit tests are collocated in the same file as the production code (`src/parser.rs` containing `#[cfg(test)] mod tests { ... }`). Checking only for `tests/**/*.rs` falsely rejects legitimate Rust bug fixes.
* **Ruby Collocation & DSLs**: Ruby testing spans Minitest (`test/test_*.rb`) and RSpec (`spec/**/*_spec.rb`), and tests can be defined via `def test_*` or block DSLs (`it "..."`).
* **Assertion Atrophy**: Agents frequently "fix" failing tests by inserting skips (`t.Skip()`, `#[ignore]`, `skip`) or deleting assertions. Detecting and banning assertion atrophy is mandatory across all supported languages.

---

## 6. The All-or-Nothing Fallacy & The Monotonic Progressive Ratchet

Early automated remediation systems operated under a binary all-or-nothing model: if a review reported 5 defects, and the remediation successfully resolved 4 defects with comprehensive tests but left 1 partially unaddressed, the runner discarded the entire patch, executed `git reset --hard`, and marked the cycle failed or blocked.

Empirically, this all-or-nothing approach exhibits severe pathologies:

### A. The Sunk Cost of Discarded Improvements
A patch that resolves 4 out of 5 defects, passes all unit tests, passes AST cognitive complexity linters, and introduces zero regressions is strictly mathematically superior to the pre-cycle commit. Wiping it out discards verified engineering value, creates livelock where subsequent attempts struggle to re-solve all 5 defects simultaneously, and wastes immense compute.

### B. The Lexicographical Priority Invariant
If partial progress is retained, how do we prevent agents from gaming the ratchet by fixing trivial minor issues while evading difficult critical flaws?
Progress must be governed by a **Lexicographical Severity Invariant**:
$$(\Delta N_{\text{Crit}}, \Delta N_{\text{Maj}}, \Delta N_{\text{Mod}}) > 0$$

If there are open Critical defects, progress **must** reduce the count of open Critical defects ($N_{\text{Crit}}^{\text{new}} < N_{\text{Crit}}^{\text{old}}$). An attempt that resolves 2 Moderate findings but fails to reduce open Critical issues is rejected and discarded. Only when Critical issues are 0 does reduction in Major issues qualify as progress, and so forth down the hierarchy.

### C. Cognitive Relief & Laser-Focused Prompts in Round 2+
When an agent attempts remediation with 5 defects across 6 files in its context, its attention and reasoning budget are diffused. When 4 of those defects are verified resolved, feeding the entire original 5-defect prompt back into Round 2 triggers two failure modes:
1. **Context Clutter**: The model re-analyzes already-fixed code, wasting tokens and reasoning capacity.
2. **Blast Radius & Re-regression**: The model attempts to "improve" or refactor the already-fixed functions, frequently breaking the tests authored in Round 1.

By stripping resolved findings and presenting a **laser-focused prompt** targeting *only* the remaining defect—while explicitly stating the non-interference invariant on already-resolved code—Round 2 gives the agent the cognitive relief needed to solve complex edge cases cleanly.

### D. Safe Ratchet Point Preservation
If late-round attempts introduce regressions or fail to converge within the attempt ceiling (default 3), the repository does not roll back to the base SHA. It resets cleanly to `last_ratchet_sha`—the latest verified state that passed the quality gate with zero regressions. The cycle records `outcome: 'partial_remediation'`, commits and archives the verified progress, logs the remaining open issues in the summary, and advances. Progress is monotonic and permanent.

