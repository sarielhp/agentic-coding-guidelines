# Autonomous Review & Remediation Workflow

The `workflow` subsystem defines the authoritative architecture, tooling, and closed-loop engine for **autonomous adversarial code review, planning, sandbox remediation, and quality gate verification**.

It is completely **language-agnostic** and provides native audit profiles and auto-detection for **Rust**, **Go**, **Ruby**, and generic repositories.

---

## Architecture: The 5-Phase Closed Loop

Every review cycle executes an autonomous, transactionally guarded workflow:

```text
                  ┌─────────────────────────────────────────┐
                  │ Phase 1: Multi-Lens Adversarial Audit   │
                  │ (tools/audit: systems/security/...)     │
                  └───────────────────┬─────────────────────┘
                                      │
                         Defects > 0? │ (0 defects -> record clean & finish)
                                      ▼
                  ┌─────────────────────────────────────────┐
                  │ Phase 2: Isolated Sandbox Remediation   │
                  │   (bws gw -b fix-branch -- agy...)      │
                  │    - Formulate architectural plan       │
                  │    - Apply code fixes                   │
                  │    - Author unit regression tests       │
                  │    - Auto-squash-merge to branch        │
                  └───────────────────┬─────────────────────┘
                                      │
                                      ▼
                  ┌─────────────────────────────────────────┐
                  │ Phase 3: Quality Gate Verification      │
                  │   (tools/gate, GATE_CMD, or check)      │
                  │   - Automatic rollback if gate fails    │
                  │   - Optional: rebuild/reinstall binary  │
                  └───────────────────┬─────────────────────┘
                                      │
                                      ▼
                  ┌─────────────────────────────────────────┐
                  │ Phase 4: Verification & Summary         │
                  │   - Inspect diff footprint (max-diff)   │
                  │   - Differential re-audit on patch      │
                  │   - Format reviews/<NUM>_summary.md     │
                  └───────────────────┬─────────────────────┘
                                      │
                                      ▼
                  ┌─────────────────────────────────────────┐
                  │ Phase 5: Archiving & Git Sync           │
                  │   - Move artifacts to reviews/archive/  │
                  │   - Persist state (reviews/state.json)  │
                  │   - git commit & git push (optional)    │
                  └─────────────────────────────────────────┘
```

---

## The 6 Multi-Lens Audit Profiles

The engine evaluates source code across 6 specialized domain lenses:

| Profile | Domain Pillar | Primary Focus Area | Backend Affinity |
| :--- | :--- | :--- | :--- |
| **`systems`** | Systems & Concurrency | Deadlocks, race conditions, atomic writes, memory safety, async task cancellation leaks | Codex / Claude |
| **`security`** | Security & Attack Surface | Path traversal, shell/macro injection, ReDoS, credential leaks, unbounded network buffers | Claude |
| **`correctness`** | Domain Specifications | Specification conformance, format idempotency, lossy field conversions, zero values | Claude |
| **`resilience`** | Resilience & Observability | Network timeouts, HTTP 429/503 retry backoff with jitter, silent error swallowing (`.ok()`) | Claude |
| **`performance`** | Complexity & Allocations | $O(N^2)$ algorithmic comparisons, excessive heap allocations in hot loops, unbuffered I/O | Codex |
| **`cli`** | Ergonomics & Help System | One canonical interface, anti-alias-bloat, concise `-h` ($\le 20$ lines), exit code hygiene | Claude |

---

## 4:2:1 Pyramid Model Cadence

To balance deep reasoning against token cost, `review_cycle` rotates models across a 7-step sequence:

$$\text{Cadence} = [\text{Flash}, \text{Flash}, \text{Tier 1}, \text{Flash}, \text{Flash}, \text{Tier 1}, \text{Tier 2}]$$

- **Tier 0 (Gemini 3.8 Flash)**: Ultra-fast workhorse for high-frequency defect discovery at zero marginal cost.
- **Tier 1 (Claude 3.7 Sonnet / Codex)**: Balanced reasoning model for architectural and systems analysis.
- **Tier 2 (Claude 3.7 Opus / GPT-5.6-Sol)**: Flagship deep-reasoning model for complex audits.

Because the **6 audit lenses** and the **7 cadence steps** are coprime ($\gcd(6, 7) = 1$), every lens is audited by every model tier across a 42-cycle non-repeating sequence. State is persisted atomically in `reviews/state.json`.

---

## Directory Structure

```text
~/prog/standards/workflow/  (also symlinked as ~/prog/standards/review-cycle/)
├── README.md               # Architecture, invariants & quickstart guide
├── bin/
│   ├── review_cycle        # Canonical 5-phase orchestration engine
│   └── audit               # Multi-lens adversarial code auditor
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

### 2. Add Configuration (`tools/review_cycle.json`)

Create `tools/review_cycle.json` (or in repository root):

```json
{
  "target": "src",
  "gate_cmd": "tools/gate",
  "build_cmd": "tools/install",
  "audit_cmd": "tools/audit",
  "guidelines": "Adhere strictly to architectural and cognitive complexity standards (depth <= 4, branches <= 15, tiered function limits).",
  "max_diff_lines": 800
}
```

### 3. Add to `AGENTS.md`

Append the documentation block from [`templates/AGENTS_SNIPPET.md`](templates/AGENTS_SNIPPET.md) to your repository's `AGENTS.md`.

---

## CLI Usage Quick Reference

```bash
# Run a single review and remediation cycle
tools/review_cycle

# Run continuously until all 6 profiles pass clean without defects
tools/review_cycle --loop

# Inspect current rotation state, cycle count, and history
tools/review_cycle --status

# Dry-run: audit and generate review report without launching sandbox
tools/review_cycle --dry-run

# Run audit standalone on a specific profile or file
tools/audit -p security src/
```

---

## Prerequisites & Ecosystem Dependencies

The autonomous remediation phase (Phase 2) leverages Bubblewrap sandboxing and autonomous agent dispatch:
- **`bws`**: [Bubblewrap Git Worktree Sandbox](https://github.com/sarielhp/bws) (`bws gw`) creates an ephemeral, air-gapped sandbox clone with host `$HOME` protection and 1-key merge triage.
- **`agy-run-wild`**: Autonomous coding agent runner dispatched inside the `bws` sandbox.
- **`git`**: Version control and worktree management.
- **Ruby >= 3.0**: Runtime for orchestrator scripts.

