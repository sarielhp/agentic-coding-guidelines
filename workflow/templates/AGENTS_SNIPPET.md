## Autonomous Review Cycle (`tools/review_cycle`)

Single-command orchestration executing adversarial review, sandbox remediation, quality gate verification, and targeted re-verification.
Complete specification: [`~/prog/standards/workflow/README.md`](file:///home/sariel/prog/standards/workflow/README.md)

### Pipeline Execution Phases:
1. **Audit**: Runs multi-lens audit (`tools/audit`), producing `<reports-dir>/<NUM>_<profile>.md`. Deep architectural profiles route to Codex (`systems`, `performance`) and Claude (`security`, `correctness`, `resilience`, `cli`).
2. **Remediation**: Dispatches sandbox agent ([`bws gw`](https://github.com/sarielhp/bws) + `agy-run-wild` / Gemini Flash) to create `<reports-dir>/<NUM>_<profile>_plan.md`, apply fixes, author regression tests, and squash-merge.
3. **Quality Gate**: Runs quality gate (`tools/gate`, `check.rb`, or language native test/linter). If sandbox or gate fails, automatically rolls back workspace to pre-cycle commit.
4. **Targeted Re-Verification**: Re-invokes the authoritative auditor model on the patch via `tools/audit --verify-remediation` to confirm defect resolution with zero regressions. Bounded to max 2 attempts with automatic branch stashing on failure.
5. **Archive & Push**: Moves artifacts to `<reports-dir>/archive/`, records clean status in `<reports-dir>/state.json`, and pushes to remote (`--no-push` to bypass).

### Asymmetric Pair Programming Architecture:
- **Auditor & Re-Verifier**: Tier 1 Codex & Claude for deep reasoning and broad invariant verification.
- **Remediator**: Gemini Flash (`agy-run-wild`) inside Bubblewrap sandbox for fast (15–30s) bounded surgical edits.
- **Oracle**: Deterministic compilers, unit tests, and AST complexity linters (`go-audit`, `rust-audit`, `ruby-audit`).

### Invariants:
- Enforce repository sizing and cognitive complexity boundaries (e.g. `AGENTS.md`).
- Transactional rollback on failure: no broken code left on working branch.
- Mandatory regression tests: every remediated defect must introduce or update an automated test.
- No assertion atrophy: test skips and assertion deletion without replacements are rejected.

### Standard Commands:
```bash
# Run single cycle with profile affinity
tools/review_cycle

# Run continuous loop until all profiles pass cleanly without defects
tools/review_cycle --loop

# Inspect current rotation state and history
tools/review_cycle --status

# Dry-run audit without dispatching sandbox remediation
tools/review_cycle --dry-run
```
