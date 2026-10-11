# Review cycle: the repository contract

The `review-cycle` engine and its `review-audit` auditor live in `~/prog/26/ruby/review_cycle`. This directory defines their integration contract and reusable project configuration. Use the engine's README and `--help` for its CLI. `STANDARDS_DIR` supplies setup guidance and the agent snippet; runtime remediation follows the project's rules.

## Required project interface

| Item | Contract |
|---|---|
| `tools/gate` | Fast gate: required analyzers, tests, and one build. Missing required tools and failed checks exit nonzero. |
| `tools/check` | Compatibility entry point to the same gate. |
| `tools/build` | Produce or validate repository artifacts; no tests, linters, installation, commits, or pushes. |
| `tools/review_cycle.json` | Audit target, gate, build, guidelines, and review options. |
| `AGENTS.md` | Project/language rules plus the [review instructions](templates/AGENTS_SNIPPET.md). |

Adopt all helpers, entry points, and settings in the [Go](../go/README.md), [Rust](../rust/README.md), or [Ruby](../ruby/README.md) instructions before setup. Copying only one build or gate template is insufficient. Libraries need a build and gate but no installation target.

Canonical `tools/gate` and `tools/check` own build validation. The engine skips a second build after those gates. Custom/legacy gates get a separate checked build unless they declare `gate_includes_build: true`. Declare `false` for an older canonical gate that does not build. Compiler/dependency caches may be external.

## Configuration

The [JSON template](templates/review_cycle.json) audits the repository and keeps commits local:

```json
{
  "target": ".",
  "gate_cmd": "tools/gate",
  "build_cmd": "tools/build",
  "gate_includes_build": true,
  "guidelines": "Follow project AGENTS.md and the applicable language standards: nesting depth <= 4; Go/Rust decision branches <= 15; Ruby cognitive complexity <= 15; language-specific function/method and file tiers.",
  "max_diff_lines": 800,
  "push": false
}
```

| Field | Meaning |
|---|---|
| `target` | Source paths. The engine splits this string on whitespace; target paths containing spaces are unsupported. |
| `gate_cmd` | Trusted shell command for pre-flight and post-merge verification. Declare the actual project gate. |
| `build_cmd` | Build validation command, required even when the gate includes it. Use build, never install. |
| `gate_includes_build` | Optional Boolean. If omitted, canonical gates include a build and other gates need a separate build. |
| `guidelines` | Guidance appended to remediation prompts; project agent instructions also apply. |
| `max_diff_lines` | Inserted/deleted line count above which the engine warns. `strict_diff: true` or `--strict-diff` rejects oversized remediation. |
| `push` | Defaults to false. True opts into upstream publication; `--push`/`--no-push` override it. |

Optional fields include `audit_cmd`, `reports_dir`, `strict_tests`, and `max_cycles`. Strict tests reject detected test skips/assertion deficits; they do not prove each defect has a regression test. Looping defaults to seven cycles and may stop before convergence.

Use `--config PATH` to select a configuration. Discovery checks tools/review_cycle.json, config/review_cycle.json, review_cycle.json, .review_cycle.json, then .review.json. Explicit CLI options and relevant environment variables override config, which overrides defaults. An explicitly missing file, malformed JSON, non-object document, unknown fields, incorrect field types, or invalid numeric bounds fail rather than restoring defaults. Omit unused fields rather than writing null or empty strings.

Gate/build commands are trusted shell strings, unlike the argument arrays in language tooling settings. Auditor overrides use shell quoting to split arguments and face the auditor version agreement check.

## Onboarding

Install the engine, auditor, host dependencies, and project analyzers as separately authorized setup work. The engine's `tools/install review-cycle review-audit` builds/copies executables; `--link` selects development symlinks.

After adopting language tooling, copy and adapt the configuration only if none exists:

```bash
rtk proxy cp ~/prog/standards/workflow/templates/review_cycle.json tools/review_cycle.json
rtk proxy review-cycle --setup
rtk proxy review-cycle --doctor
rtk proxy tools/gate
```

Setup requires executable tools/build and a resolvable gate before configuring bws, and points missing-tooling errors to complete language adoption instructions. It configures local bws profiles/tool mounts, runs the doctor, creates missing config, adds ignore entries, and refreshes the recognized `## Autonomous review cycle` agent section from the standards snippet. Other agent sections and existing configuration are preserved. Custom review sections receive a reconciliation notice. Ruby projects receive .ruby-version when absent.

Existing explicit push:true settings remain enabled; inspect them when adopting this policy. Configs without push now default to local commits. Setup preserves bws trust checks and never grants trust automatically.

Doctor checks Ruby, Git/repository context, bws, the runner, auditor, and configured sandbox tools/gems, including bounded runner help execution. It does not configure bws or replace the gate.

## Running and publishing

```bash
rtk proxy review-cycle                     # local commits by default
rtk proxy review-cycle --no-push           # override push-enabled config
rtk proxy review-cycle --loop --no-push    # bounded multi-lens loop
rtk proxy review-cycle --status
rtk proxy review-cycle --dry-run --no-push # audit/report; pre-flight gate still runs
# When publication is authorized:
rtk proxy review-cycle --push
```

Review may checkpoint tracked edits, commit reports, squash-merge fixes, archive artifacts, and update state. Dry runs invoke the auditor, create logs/ignore files and defect reports, and run the pre-flight gate unless skipped. They skip checkpointing, remediation, state advancement, commits, and pushes. They are not read-only.

The six lenses are systems, security, correctness, resilience, performance, and cli, with a seven-step 4:2:1 model-tier cadence. Reports use <reports-dir>/<NUM>_<profile>.md, plans use <NUM>_<profile>_plan.md, and summaries use <NUM>_summary.md. Reports default to reviews (or existing reports); archive/log directories are ignored and state.json holds history.

Missing verification commands and failed Git operations stop the run. `--skip-gate` skips only pre-flight execution; post-merge verification remains required. Differential-audit errors, invalid responses, and findings at any severity reject remediation and trigger rollback. `--skip-diff-audit` retains local fixes, records `needs_review`, exits nonzero, and prevents both per-cycle and batched publication.

Publication requires an attached branch with a configured remote branch upstream and exactly one push URL. The engine validates it before review, pushes the intended commit to that exact branch, then queries the same destination and requires its SHA to match. Single-cycle and batched pushes use the same checked routine. Rejected pushes, query failures, and SHA mismatches exit nonzero and retain verified local commits. A verification query can fail after an accepted push; inspect the remote before retrying.

Review commits do not contain lifecycle structured verification records or create release tags. Run the full project gate before authorized publication or use tools/bump/tools/release. Installation remains the explicitly authorized project tools/install operation.

## Verification boundaries

- Missing regression-test edits remain advisory. Test-weakening and diff-size rejection require strict options; neither proves coverage.
- Rollback restores tracked work to the cycle base and preserves pre-existing untracked files. Ignored output/cache changes and external effects remain outside rollback.
- Canonical gates must honor their declared build contract. Declare build ownership explicitly for different gates.
- A clean audit means the configured auditor reported no findings in the selected scope; it is not proof of correctness.

Keep sandboxing and manual approval review enabled, reuse session authorization, and publish/install only within the user's authorized scope.
