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
