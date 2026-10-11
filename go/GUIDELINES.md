# AI Agentic Go Guidelines & Engineering Standards

## 1. Overview & Core Philosophy

This standard establishes principles, complexity limits, and Google Go idioms tailored for both human engineers and autonomous AI coding agents. 

The core objective is **cognitive clarity and correctness**. Lines of code are merely a secondary proxy; the primary correctness metric is **cognitive complexity** (nesting depth, branch density, and mental state tracking).

---

## 2. Structural Complexity Limits

Code must maintain low branching and nesting complexity so it can be verified, audited, and refactored without subtle regressions.

### Nesting Depth — Hard Limit 4 (Warn at 3)
- No Go function may exceed **4 levels of control-flow nesting** (`if`, `for`, `switch`, `select`).
- Deeply nested blocks must be flattened using guard clauses and early returns.

### Branch Decision Points — Hard Limit 15
- A standard function may contain at most **15 decision points** (`if`, `for`, `switch`, `select`).
- **Flat Switch Exemption**: A `switch` block counts as 1 decision point; individual flat `case` branches that delegate directly do not increment the branch count.
- **Builders & Dispatchers**: Allowed up to 20 decision points.

---

## 3. Function Sizing — Cognitive Tiering

Rather than a blanket line limit, function thresholds are tiered by architectural role:

| Tier | Function Type / Naming Patterns | Comfort Range | Soft Warn | Hard Limit |
|---|---|---|---|---|
| **Standard Logic** | General business logic, handlers, computations, algorithms | 20–60 lines | 80 lines | **110 lines** |
| **Declarative Builders** | `build*`, `init*`, `render*`, `generate*`, `View`, UI layout | 40–100 lines | 120 lines | **160 lines** |
| **Event / Key Dispatchers** | `handle*`, `dispatch*`, `*Key`, `*Route` (cases delegate to helpers) | 50–120 lines | 150 lines | **200 lines** |
| **Table-Driven Tests** | `Test*` functions declaring test struct slices and assertion loops | 50–150 lines | 180 lines | **250 lines** |

---

## 4. Google Go Style & Quality Rules

### Control Flow & "Line of Sight"
- **Left-Aligned Happy Path**: Keep the primary execution path aligned to the left margin. Evaluate pre-conditions, input validation, and nil checks first using guard clauses (`if err != nil { return ... }`) and return early.
- **Strict Ban on `else` After Terminal Statements**: If an `if` block ends with `return`, `continue`, `break`, or `panic`, an `else` or `else if` block is strictly forbidden. Dedent the subsequent code.
- **Loop Filtering via `continue`**: Filter collections at the top of `for` loops using `continue` instead of wrapping loop bodies in nested conditionals.

### Language Idioms
- **Ban Naked Returns**: Never use naked returns (`return` with no arguments) in functions declaring named return values. Return explicit values (`return val, err`).
- **Contextual Error Wrapping**: Wrap errors with `fmt.Errorf("action description: %w", err)`. Never silently drop errors with `_ = ...` without explicit inline justification. Error strings must be lowercase without trailing punctuation.
- **Declaration Proximity**: Declare variables immediately prior to their first use rather than grouping declarations at the top of the function.
- **Receiver Discipline**: Use short, mnemonic receiver names (1–3 characters, e.g. `m` for model, `s` for server). Never use `this` or `self`. Maintain uniform pointer receivers across methods on the same type.

---

## 5. Anti-Decomposition Rules for Agents

When refactoring functions that exceed complexity limits, agents must follow strict decomposition discipline:

1. **No Artificial Continuation Helpers**: Never extract artificial sequential fragments like `processPart2()`, `handleStepB()`, or `runRemainder()`. Every extracted helper must represent a single, cohesive, domain-named responsibility (e.g. `findNextEvent`, `combineEventFields`, `parseCachedCalendars`).
2. **No Parameter Dumping**: Do not extract a helper if it requires more than 4 parameters or passing pointers to local variables just to share local state. If state transitions are linear, keep them in place and simplify using guard clauses or table-driven data structures.
3. **Decompose in Place First**: Always decompose oversized functions in place into named helpers in the same file before moving logical modules into new files. Never split a file across a function body.

---

## 6. File Sizing Guidelines

- **Comfort Metric (300–700 lines)**: Keeping functions under cognitive limits keeps files naturally within the 300–700 line range.
- **Warning Threshold**: 800 lines (soft warning).
- **Hard Limit**: 1100 lines (1600 lines for test files `*_test.go`).
- **File Modularity**: Group files by cohesive architectural responsibility (e.g. `api.go`, `models.go`, `display.go`, `cache.go`).

---

## 7. Quality Gates & Enforcement Tooling

Compliance is automated via two complementary tooling tiers:

### Fast Daily Gate (`go-audit` & `make check`)
- Run on every commit or file save.
- Checks formatting (`gofmt -s`), compiler analysis (`go vet`), baseline-aware linting (`staticcheck`), cognitive sizing limits (`go-audit`), and offline tests (`go test`).

### Deep Static Review (`go-static-analysis`)
- Run periodically, before major commits, or before releases.
- Deploys deep AST analyzers:
  - `gocritic`: Logic bugs, branch symmetries, redundant conditionals, anti-patterns.
  - `shadow`: Variable shadowing across nested scopes.
  - `revive`: Go idioms, style hygiene, unused parameters, naming conventions.
  - `govulncheck`: Call-graph dependency CVE vulnerability checks.
  - `dupl`: Structural AST clone and duplicate code detection.

## 8. Repository Tooling Interface

Every Go repository supplies a repository-local `tools/build` and a quality gate.
The copied [templates](templates/) supply the following common interface:

| Command | Contract |
|---|---|
| `tools/build` | Produce or validate repository-local artifacts; no tests, linters, installation, or Git mutations |
| `tools/gate` / `tools/check` | Equivalent entry points to one quality-gate implementation; `--full` selects release checking |
| `tools/lint` | Fast static checks, without tests, artifact builds, or Git mutations |
| `tools/snapshot [message]` | Local checkpoint commit without a gate or push |
| `tools/commit [--full] <message>` | Gate, stage, commit, and record verification; no push |
| `tools/bump [--resume]` | Validate, bump patch version, commit, explicitly push to the configured upstream, and verify remote SHA; no installation |
| `tools/install` | Build, install only to declared authorized targets, and compare installed contents with the built artifact |
| `tools/release [--install] <message>` | Coordinate gated commit, full release checking, bump, verified push, and opt-in installation; stop at the first failure |

Make targets delegate to these scripts. Keep `tools/gate` and `tools/build`
compatible with the review-cycle contract; `tools/check` loads the same gate.
Libraries need build and quality checks, but need not invent installation or
versioned releases. Unsupported commands fail clearly.

### Project Settings and Artifact Containment

Copy `settings.rb` and `tooling.rb` beside the entry points; they have no runtime
dependency on this standards checkout. Adapt the explicit settings for build
packages, artifact-to-package mappings, CLI layouts, installation targets,
version storage, version update commands, and additional checks. The example
detects a root main package and writes `bin/<project>`; libraries validate
`./...`; `cmd/` projects declare their entry points. Root binaries are supported.

Validate every artifact's path and existing symlink ancestors **before any
build writes**. Repository artifacts stay inside the repository; Go's ordinary
module and compiler caches can live outside it. Ignore built artifacts in Git.
Never overwrite source files, control files, or an undeclared installation target.

Resolve executable paths using explicit project overrides, configured GOBIN and
GOPATH/bin locations, PATH, and the customary `~/.go/bin` and `~/go/bin` fallbacks.
Missing required tools fail; bootstrap installation is a separately authorized
operation. Use argument arrays for subprocesses and check every exit status.

### Fast and Full Gates

The fast gate checks formatting without modifying sources, module tidiness,
vet, staticcheck, strict cognitive audit, project checks, and tests, then calls
`tools/build` once. `tools/lint` owns vet, staticcheck, and the cognitive audit.
The full gate additionally runs race tests, vulnerability checking, deep AST
review (gocritic, shadow, revive, dupl), and configured full project checks,
before the final build. Runtime depends on the project and tool caches.

Baselines are explicit reviewed records, never automatically enlarged. Compare
finding **counts**, so a repeated finding cannot disappear through set
deduplication. Analyzer execution failures, missing tools, or malformed reports
are failures even when a baseline exists. Staticcheck baselines contain exact
JSON diagnostic records; go-audit baselines contain exact ANSI-free `[FAIL]`
lines. Hard audit findings are enforced using `--strict`. Soft warnings remain
advisory. Changes to analyzer formats require an explicit adapter review.

### Verification and Releases

Verification records live in Git metadata, separate from staged project files.
They include the checked HEAD, gate level, and a digest of tracked and unignored
untracked file contents and modes, copied tools (including ignored tools), Go
configuration, and analyzer executable identities. A fast record, old SHA-only
marker, changed source, changed tool settings, or changed required input cannot
substitute for full verification. Commit hooks that alter checked inputs prevent
recording verification. Declare additional ignored/generated inputs in the
digest when adapting a project; keep environment-sensitive checks explicit.

The default embedded-version mode changes version metadata and runs the full
gate against that version before committing. Version update commands run before
the gate and cannot exempt changed source from checking. For metadata-only
versions, full verification can be reused only for an otherwise identical HEAD
and inputs, with VERSION excluded from the digest and `go list` confirming that
it is not embedded in a Go package. Even then, build the versioned artifact.
The release orchestrator runs the fast commit gate followed by one full bump
gate. It does not claim a fast commit is release-verified.

Bump validates semantic version syntax, clean working tree, attached branch,
and upstream remote/ref before modifying files. It pushes the release commit
explicitly to that ref without force, then queries the same remote/ref and
compares its SHA. Failures preserve local files and commits. A pending-release
record prevents a second bump. Resolve the upstream's single push URL and use
that URL for both push and verification. After a failed push or remote query, inspect
local state and use `tools/bump --resume` to retry the same commit. Earlier
check/commit failures require inspection and repair; resume can full-check and
commit the pending version when the original HEAD and pending version still match.
Never blindly repeat bump.
Do not pull, merge, rebase, or synchronize unrelated refs automatically.

Installation compares contents and preserves executable mode; it does not commit,
push, change completions, or remove legacy software. A successful verified push
followed by failed installation remains a published release; report the failed
installation separately. Tool execution approval and task authorization are
distinct: templates do not edit agent approval rules or sandbox writable roots.
