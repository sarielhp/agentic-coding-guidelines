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

## 7. Quality Gates & Enforcement Tooling

Compliance is automated via two complementary tooling tiers:

### Fast Daily Gate (`ruby-audit` & `make check`)
- Run on every commit or file save.
- Checks Ruby syntax (`ruby -cw`), AST cognitive limits & sizing (`ruby-audit`), and unit tests (`rake test` or `minitest`).

### Deep Static Review (`ruby-static-analysis`)
- Run periodically, before major releases, or in CI.
- Runs:
  - `rubocop`: Style hygiene, layout, and idiomatic Ruby linting.
  - `bundle-audit`: Security vulnerabilities in dependencies (Ruby Advisory Database).
  - `dupl`: Structural AST clone and duplicate code detection.
