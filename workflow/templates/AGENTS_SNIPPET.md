## Autonomous Review Cycle (`tools/review_cycle`)

Single-command orchestration executing adversarial review, sandbox remediation, and quality gate verification.
Complete portable specification: [`tools/REVIEW_CYCLE.md`](tools/REVIEW_CYCLE.md)

### Pipeline Execution Phases:
1. **Audit**: Runs multi-lens audit (`tools/audit`), producing `<reports-dir>/<NUM>_<profile>.md`.
2. **Remediation**: Dispatches sandbox agent ([`bws gw`](https://github.com/sarielhp/bws) + `agy-run-wild`) to create `<reports-dir>/<NUM>_<profile>_plan.md`, apply fixes, author regression tests, and squash-merge.
3. **Quality Gate & Rollback**: Runs quality gate (auto-detected or `--gate-cmd`). If sandbox or gate fails, automatically rolls back workspace to pre-cycle commit.
4. **Verification & Summary**: Inspects diff footprint (`--max-diff-lines`), runs differential re-audit on patch (`tools/audit`), and generates `<reports-dir>/<NUM>_summary.md`.
5. **Archive & Push**: Moves artifacts to `<reports-dir>/archive/`, records `<reports-dir>/state.json`, and pushes to remote (`--no-push` to bypass).

### 4:2:1 Pyramid Cadence & 6-Lens Balancing:
Rotates models: `[Flash, Flash, Tier 1, Flash, Flash, Tier 1, Tier 2]` (4 Gemini Flash : 2 Claude/Codex : 1 Opus).
Round-robins across the 6 audit lenses (`systems`, `security`, `correctness`, `resilience`, `performance`, `cli`).
Because $\gcd(6, 7) = 1$, every lens is audited by every model tier over a 42-cycle non-repeating sequence.

### Invariants:
- Enforce repository sizing and architectural invariants (e.g. `AGENTS.md`).
- Transactional rollback on failure: no broken code left on working branch.
- Mandatory regression test for every remediated defect.

### Standard Commands:
```bash
# Run single cycle with automatic profile & model rotation
tools/review_cycle

# Run continuous loop until all 6 profiles pass cleanly without defects
tools/review_cycle --loop

# Inspect current rotation state and history
tools/review_cycle --status

# Dry-run audit without dispatching sandbox remediation
tools/review_cycle --dry-run
```
