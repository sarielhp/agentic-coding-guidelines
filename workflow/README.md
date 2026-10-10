# Review Cycle: the Repository Contract

The autonomous review-and-remediation engine (`review-cycle`) lives in its own repository:
**`~/prog/26/ruby/review_cycle`** (`git@gitlab.com:sarielhp-priv/prog/26/ruby/review_cycle.git`),
installed as `~/bin/review-cycle` via its `tools/install --link review-cycle`.

This directory holds only what a repository must provide so the engine can drive it.
The engine reads the standards from `STANDARDS_DIR` (default `~/prog/standards`) for setup hints.

## What a repository provides

| Item | Purpose | Provided by |
|---|---|---|
| `tools/gate` | Tier 1 quality gate; the engine rolls back any remediation that fails it | language `templates/gate.rb` |
| `tools/build` | Rebuild after remediation; repo-local, no tests or linters (see the contract in the top README) | language `templates/build.rb` |
| `tools/audit` | Multi-lens LLM auditor; symlinked to the engine's bundled `bin/audit` by `review-cycle --setup` | engine |
| `tools/review_cycle.json` | The contract below | `review-cycle --setup` or [`templates/review_cycle.json`](templates/review_cycle.json) |
| `AGENTS.md` block | Tells agents how the cycle works | [`templates/AGENTS_SNIPPET.md`](templates/AGENTS_SNIPPET.md) |

## `tools/review_cycle.json`

```json
{
  "target": "src",
  "gate_cmd": "tools/gate",
  "build_cmd": "tools/build",
  "audit_cmd": "tools/audit",
  "guidelines": "Adhere strictly to architectural and cognitive complexity standards (depth <= 4, branches <= 15, tiered function limits).",
  "max_diff_lines": 800
}
```

- `target`: directory or file the audit lenses read.
- `gate_cmd`: must exit non-zero on any regression; the engine never auto-commits past a failing gate.
- `build_cmd`: must be side-effect free outside the repository. The engine never guesses `tools/install` here.
- `audit_cmd`: the auditor executable; `tools/audit` by convention.
- `guidelines`: one sentence injected into every remediation prompt.
- `max_diff_lines`: remediation diffs above this are flagged (`--strict-diff` rolls them back).

## Onboarding

```bash
review-cycle --setup    # doctor, tools/audit symlink, tools/build check, .ruby-version (Ruby), config, .gitignore, AGENTS.md
review-cycle --doctor   # prerequisites: ruby >= 3.0, git, bws, agy-run-wild, auditor
```

Everyday use, cadence, profiles and flags are documented in the engine repository's README.
