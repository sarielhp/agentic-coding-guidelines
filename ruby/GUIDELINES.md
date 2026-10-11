# AI Agentic Ruby Guidelines & Engineering Standards

## 1. Overview & Core Philosophy

This standard establishes architectural principles, cognitive complexity boundaries, and idiomatic Ruby conventions tailored for both human engineers and autonomous AI coding agents.

The core objective is **cognitive clarity and correctness**. Lines of code are merely a secondary proxy; the primary correctness metric is **cognitive complexity** (nesting depth, branch density, and mental state tracking).

---

## 2. Structural Complexity Limits

Code must maintain low branching and nesting complexity so it can be verified, audited, and refactored without subtle regressions.

### Nesting Depth — Hard Limit 4 (Warn at 3)
- No Ruby method may exceed **4 levels of control-flow nesting** (`def` → L1 → L2 → L3 → L4).
- Reaching level 5 requires immediate helper extraction or guard clause flattening.
- **Resource Block Flattening**: Pure resource management and isolation blocks (`File.open`, `Dir.chdir`, `Mutex#synchronize`, `with_lock`) provide deterministic safety without branching logic. They are treated as flat scopes rather than conditional decision nesting.

### Cognitive Complexity — Hard Limit 15 (Warn at 10)
- A method must not exceed a cognitive complexity score of **15** (computed via AST analysis of conditional branches, iterative loops, rescue blocks, and boolean operators).
- Nested control structures incur compounding cognitive penalties ($1 + \text{depth}$).
- Control jumps, nested branches, and state-dependent logic must be decomposed into cohesive named helpers.

---

## 3. Method Sizing — Cognitive Tiering

Rather than a blanket line limit, method thresholds are tiered by architectural role:

| Tier | Method Type / Patterns | Comfort Range | Soft Warn | Hard Limit |
|---|---|---|---|---|
| **Standard Logic** | Computations, handlers, algorithms, parsers, state transitions | 20–50 lines | 60 lines | **80 lines** |
| **Declarative Builders** | DSL declarations, `OptionParser` specs, UI/text layout, configuration mappings | 40–90 lines | 100 lines | **120 lines** (if CC $\le 5$) |
| **Dispatchers & Routers** | Linear event/command dispatchers where branches delegate to helpers | 40–100 lines | 120 lines | **150 lines** |
| **Test Cases** | `test_*` / `it` blocks declaring data fixtures, step executions, and assertions | 30–100 lines | 120 lines | **150 lines** |

- **Declarative Complexity Ceiling**: Methods exceeding 80 lines up to the 120-line ceiling are permitted **if and only if** their Cognitive Complexity is $\le 5$.
- **Standalone CLI & Procedural Scripts**: Single-purpose scripts and CLI tools do not require class or module wrappers. Flat procedural execution using top-level guard clauses (`abort "..."`, `exit 1`) is officially supported and idiomatic. Sizing rules govern methods; procedural top-level scripts are governed by the file limits and cognitive nesting depth ($\le 4$).

---

## 4. Idiomatic Ruby Style & Quality Rules

### Control Flow & "Line of Sight"
- **Left-Aligned Happy Path**: Keep the primary execution path aligned to the left margin. Evaluate pre-conditions, input validation, and nil checks first using guard clauses (`return unless valid?`, `return if item.nil?`) and return early.
- **Strict Ban on `else` After Terminal Statements**: If an `if` block ends with `return`, `raise`, `fail`, `break`, or `next`, an `else` or `elsif` block is strictly forbidden. Dedent the subsequent code.
- **Loop Filtering via `next`**: Filter collections at the top of `each`/`for` loops using `next unless valid?` or `next if condition` instead of wrapping entire loop bodies in nested conditionals.

### Language Idioms & Safety
- **Exception Safety Hierarchy**:
  - Always rescue `StandardError` or specific domain exceptions (`rescue StandardError => e` or bare `rescue => e`).
  - **Strictly never rescue `Exception`**. Rescuing `Exception` traps `SignalException`, `Interrupt`, and `SystemExit`, preventing clean program termination and signal propagation.
  - **Ban Bare `rescue nil`**: Never silently swallow exceptions without explicit inline justification and logging. Always preserve or wrap the error context.
- **Process & Command Execution Safety**:
  - Always pass multi-argument arrays to `Open3.capture2`, `Open3.capture3`, `system`, or `Process.spawn` (e.g. `system('git', 'checkout', branch)`).
  - Never interpolate unsanitized strings into shell commands (`system("cmd #{arg}")`). If shell evaluation is mandatory, sanitize with `Shellwords.escape`.
- **Resource Lifecycle in `ensure` Blocks**:
  - Temporary files, locks, background PTYs, and working directory state must be guaranteed cleanup within `ensure` blocks.
- **Data vs. Logic Separation**:
  - Large lookup tables, regular expressions, explanation dictionaries, and configuration mappings must live in frozen module or class constants (`.freeze`), never instantiated inside method bodies.
- **Type Safety & Nil Hygiene**:
  - Use safe navigation (`&.`) when values may legitimately be nil (`user&.name`).
  - Use predicate methods ending in `?` (`valid?`, `empty?`) and mutating or exception-raising variants ending in `!` (`save!`, `normalize!`).

### Memory & Performance Hygiene
- **Immutable String Deduplication**: Include `# frozen_string_literal: true` at the top of every Ruby file.
- **String Mutation in Hot Loops**: Use in-place string mutation (`str << chunk`) or array joins (`chunks.join`) instead of repeated heap allocations with `str += chunk`.
- **Precompiled Regexp**: Define regular expressions as frozen constants or compile them once. Use the `/o` flag if interpolating once in inner loops.

### Ruby-Specific Gotchas & Agent Traps
- **The Truthiness Trap (`0`, `""`, `[]` are Truthy)**:
  - In Ruby, only `nil` and `false` are falsy. Integer `0`, empty strings `""`, and empty collections `[]` evaluate to `true`.
  - Never write `if items` or `unless count` expecting falsiness on empty/zero. Use explicit presence predicates:
    - Collections: `items.any?` or `!items.empty?`
    - Integers/Floats: `count.positive?` or `count > 0`
    - Strings: `!str.empty?` or `str.strip.empty?`
- **Block Control Flow: Non-Local `return` vs. `next`**:
  - `return` inside a block returns from the **enclosing method**, not the block.
  - Never use `return` inside `.each`, `.map`, or iteration blocks unless an immediate abort of the entire caller method is explicitly intended.
  - Always use `next` to skip to the next iteration (equivalent to loop `continue`), and `break` to terminate iteration early.
- **The `Hash.new(default)` Shared Mutable Object Hazard**:
  - `Hash.new([])` or `Hash.new({})` binds a single shared object across all missing keys. Mutating it (`h[k] << v`) corrupts the default object for all keys.
  - Always use the block constructor for mutable defaults: `Hash.new { |h, k| h[k] = [] }`.
- **Hash Key Type Incoherence (Symbol vs. String) & Nil Punning**:
  - Ruby standard hashes treat `:foo` and `"foo"` as distinct keys. Missing keys return `nil` silently, masking bugs until downstream execution.
  - Standardize key types upon parsing (`JSON.parse(str, symbolize_names: true)`).
  - Use `hash.fetch(:key)` when values are mandatory to enforce fail-fast behavior.
- **Ruby 3 Keyword Arguments (`kwargs`) Separation**:
  - Ruby 3.0+ strictly separates positional hashes from keyword arguments.
  - When passing a hash to a method expecting keyword arguments, explicitly splat with double-splat: `method(**options)`.
- **Ban on Global Core Class Pollution (Monkey Patching)**:
  - Never reopen standard library or core classes globally (`class String`, `class Array`).
  - Encapsulate helpers in pure utility modules (`StringUtils.sanitize(str)`).
  - If syntax extension is strictly necessary, scope it using **Refinements** (`refine String do ... end` + `using ...`) to isolate modifications to the current file.
- **Deep Freezing of Constants**:
  - Calling `.freeze` on an Array or Hash is shallow: internal elements remain mutable.
  - Freeze nested arrays, strings, and hashes, or define immutable frozen structures.
- **Binary vs. UTF-8 Stream Encoding**:
  - Standard `File.read` assumes UTF-8 text encoding. Reading binary artifacts (PDFs, images, compressed bundles) with `File.read` causes `ArgumentError: invalid byte sequence in UTF-8`.
  - Always use `File.binread`, `File.binwrite`, or open with binary mode `'rb'` when handling binary files.

---

## 5. Anti-Decomposition Rules for Agents

When refactoring methods that exceed complexity or line limits, AI coding agents must follow strict decomposition discipline:

1. **No Artificial Continuation Helpers**: Never extract artificial sequential fragments like `process_part_2()`, `handle_step_b()`, or `run_remainder()`. Every extracted helper must represent a single, cohesive, domain-named responsibility (e.g. `resolve_target_files`, `parse_log_entry`, `verify_checksum`).
2. **No Parameter Dumping**: Do not extract a helper if it requires passing 5 or more local variables or mutating intermediate state across arbitrary boundaries. If state transitions are linear, keep them in place and simplify using guard clauses, enumerable pipelines, or cohesive structs.
3. **Decompose in Place First**: Always decompose oversized methods in place into private helpers within the same class or module before splitting into new files. Never split a file across a method body.

---

## 6. File Sizing Guidelines

- **Comfort Range**: 300–700 lines. Keeping methods under cognitive limits keeps files naturally modular.
- **Warning Threshold**: 800 lines (soft warning).
- **Hard Ceiling**: 1100 lines.
- **Exemptions**: Static lookup tables, serialized error catalogs, and data dictionary files are exempt from the hard file limit provided they contain minimal operational logic.

---

## 7. Quality gates and enforcement tooling

| Scope | Required validation |
|---|---|
| One standalone file, at most 150 lines, no lockfile | `ruby -cw` and strict `ruby-audit`. Choose `PROFILE = :script` in copied workflow settings. |
| One larger script | Strict `ruby-audit` and `ruby-static-analysis <file>`: syntax plus RuboCop with project configuration or the standards baseline. |
| Multiple source files, a project, or a lockfile | Fast gate: syntax, strict AST audit, RuboCop, and tests. Full gate: also bundle-audit when a lockfile exists and Ruby AST clone review with Flay. |

Standalone mode automatically becomes project mode when application sources exceed one file or 150 lines, or `Gemfile.lock` exists. Copied lifecycle helpers do not themselves promote a small script into a project. Projects require a local `.rubocop.yml` and should pin Ruby with `.ruby-version`; use [templates/dot_rubocop.yml](templates/dot_rubocop.yml) as the starting point. Syntax warnings and errors fail the build.

`ruby-audit` uses RubyVM's AST to enforce the existing method/file tiers, nesting depth (at most 4), cognitive complexity (at most 15), idioms, and agent trap rules. These limits remain unchanged.

`ruby-static-analysis` discovers Ruby extensions and extensionless Ruby executables. By default it runs syntax and RuboCop; directory/multiple-file reviews also run Flay and bundle-audit when a lockfile exists. Single-file reviews omit repository clone/dependency checks unless explicitly selected. Explicit `--syntax`, `--rubocop`, `--vuln`, or `--dups` flags select only those checks. Missing required tools and failed checks always exit nonzero; `--strict` is accepted for compatibility.

The standalone wrapper searches upward from target files for `.rubocop.yml`; different project configurations require separate reviews. Without project configuration it uses the standards baseline and current interpreter version. Flay's `--threshold` sets its mass threshold (default 50); any reported clone score fails. Parser skips, stderr diagnostics, or an invalid report also fail. See [Flay](https://github.com/seattlerb/flay) for its Ruby AST comparison model. The previous Go-specific `dupl` adapter is removed.

Tests load all discovered minitest files once in one process; failures propagate directly. Use an explicit `TEST_COMMAND` array for RSpec, Rake, or other frameworks. An empty test selection is reported. No shell fallback substitutes a different test command after a failure.

## Repository lifecycle

Copy the templates into the project; the helpers load project-local settings and never load a live standards checkout. Configure `tools/settings.rb` before use. Make targets delegate to the same executable scripts.

| Command | Behavior |
|---|---|
| `tools/build` | Produce or validate repository artifacts; no tests, linting, installation, or publication. |
| `tools/lint` | Required fast analyzers; missing executables and failed subprocesses stop the command. |
| `tools/test` | Run the configured language test suite. |
| `tools/gate`, `tools/check` | Identical fast gate, with one build and one test run. Add `--full` for deep review. |
| `tools/snapshot [message]` | Ungated local checkpoint, bypassing commit hooks; use only when a checkpoint is intended. |
| `tools/commit [--full] <message>` | Gate, stage, and commit locally. A structured verification record can reuse checks only for matching HEAD, inputs, tools, environment, and check level. |
| `tools/bump [major\|minor\|patch]` | Require a clean tree and configured branch upstream; update version, run the full gate, commit, tag, and push. Default is patch. |
| `tools/bump --resume` | Resume an inspected interrupted release at its pending version, never bumping again. |
| `tools/install [names...]` | Build, then install only selected declared artifacts to declared absolute destinations; verify bytes and executable permissions. |
| `tools/release [--install] <message>` | Local gated commit followed by full-checked bump and verified publication. Installation requires `--install`. |

Bumps never trust the old `.verified_head` marker or assume a version-only edit is safe. Version changes, lock synchronization, and version-generation commands happen before checks. Publication pushes only the release commit to its configured upstream branch and the requested annotated tag; it verifies the exact remote branch and peeled tag commit. No unrelated tags are pushed. The remote must support atomic pushes. `RELEASE_TAG = false` explicitly disables tagging.

An interrupted bump leaves files, commits, tags, and `.git/tooling-release.json` available for inspection. Repair the cause and use `--resume`; a committed release rejects changed HEAD, worktree, or checked inputs. If installation fails after publication, the command reports that publication succeeded and installation failed. It does not claim the release was rolled back.

Installation is disabled until `INSTALL_TARGETS` declares artifact-to-destination mappings. Libraries can use `ARTIFACTS = []`. Undeclared names, escaping artifact paths, and unrelated destination symlinks fail. Checking or committing never installs. Tool bootstrap is a separate authorized action; missing analyzers never trigger installation.

`TOOLS` supplies explicit executable overrides. `FAST_CHECKS`, `FULL_CHECKS`, and `VERSION_UPDATE` contain argument arrays, not shell strings. Declare ignored generated/configuration inputs in `VERIFICATION_INPUTS`; verification includes tracked and unignored files, copied tooling, required language inputs, tool identities, and relevant environment. Compiler and dependency caches may be external; project artifacts remain inside the repository.

Run routine checks for authorized work and reuse authorization given in the session. Command approval permits execution; it does not authorize unrelated publication, installation, or filesystem writes. Keep sandboxing and manual approval review enabled. Read [templates/AGENTS_SNIPPET.md](templates/AGENTS_SNIPPET.md) for exact command forms.
