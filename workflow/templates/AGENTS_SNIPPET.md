## Autonomous review cycle (`review-cycle`)

The engine and review-audit live in ~/prog/26/ruby/review_cycle and run from PATH. The repository contract is ~/prog/standards/workflow/README.md; project choices belong in tools/review_cycle.json. Read project/language guidelines, agent instructions, and tooling settings before remediation.

| Command | Effect |
|---|---|
| `rtk proxy review-cycle --doctor` | Check host and configured sandbox prerequisites. |
| `rtk proxy review-cycle --setup` | Requested onboarding: configure local bws profiles/tools and project review files. |
| `rtk proxy review-cycle --no-push` | Requested audit/remediation with local commits, gate/build, and differential verification. |
| `rtk proxy review-cycle --loop --no-push` | Bounded loop across lenses; default maximum seven cycles. |
| `rtk proxy review-cycle --push` | Authorized upstream publication with remote SHA verification. |
| `rtk proxy review-cycle --status` | Inspect rotation and history. |
| `rtk proxy review-cycle --dry-run --no-push` | Audit/report without remediation or commits; writes reports/logs and runs pre-flight checks. |

Declare executable tools/gate and tools/build. Adopt all language helpers, entry points, and settings. The canonical gate owns analyzers, tests, and one build; tools/check delegates to it. Build validates repository artifacts and never installs or changes Git. Compiler/dependency caches may be external. Custom gates need a checked separate build unless gate_includes_build:true declares they include it.

The pipeline audits a lens, dispatches sandbox remediation, inspects its diff, runs the post-merge gate/build and differential audit, then writes summary/archive/state artifacts. Invalid configuration, missing commands, failed verification, and failed Git operations stop the run. Remediation or verification failures roll back to the cycle base with pre-existing untracked-file preservation. Ignored output/cache changes and external effects remain outside rollback.

Every differential finding blocks completion. --skip-diff-audit records local needs_review, exits nonzero, and prevents publication. Engine evidence overrides agent-authored verification claims in summaries. Preserve regression coverage and add appropriate defect tests. Missing test edits remain advisory; --strict-tests rejects detected test weakening and --strict-diff rejects oversized diffs. Neither proves complete coverage.

Commits remain local by default; inspect existing explicit push:true settings and use --no-push when needed. Authorized publication requires a remote branch upstream and one push URL, pushes the exact intended commit, and verifies its destination SHA. Publication failures exit nonzero and retain verified local commits; inspect the remote before retrying. Batched pushes follow the same policy.

Review commits do not contain lifecycle structured verification or create release tags. Run the full project gate before authorized publication or use tools/bump/tools/release. Install only through the explicitly authorized project installation workflow.

Command approval permits execution, not unrelated work. Reuse session authorization. Keep sandboxing and manual approval review enabled; never enlarge writable roots, modify approval rules, install dependencies, or publish merely because these instructions are present.
