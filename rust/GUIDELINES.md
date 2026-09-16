# AI Agentic Rust Guidelines & Engineering Standards

## 1. Overview & Core Philosophy

This standard establishes principles, cognitive complexity boundaries, and idiomatic Rust patterns tailored for human engineers and autonomous AI coding agents.

The core objective is **cognitive clarity, memory correctness, and architectural cohesion**. Lines of code are merely a secondary proxy; the primary correctness metric is **cognitive complexity** (nesting depth, branch density, mental state tracking, and borrow-scope lifetime tracking).

---

## 2. Structural Complexity Limits

Code must maintain low branching and nesting complexity so it can be verified, audited, and refactored without subtle logic bugs, lifetime conflicts, or borrow-checker regressions.

### Nesting Depth — Hard Limit 4 (Warn at 3)
- No Rust function may exceed **4 levels of control-flow nesting** (`if`, `match`, `for`, `while`, `loop`).
- Deeply nested blocks must be flattened using guard clauses, early returns, and the canonical `let-else` pattern.

### Branch Decision Points — Hard Limit 15
- A standard function may contain at most **15 decision points** (`if`, `match`, `for`, `while`, `loop`).
- **Flat Match Exemption**: A `match` block counts as 1 decision point. Flat `match` arms that destructure or delegate directly to named helper functions do not increment the branch count.
- **Declarative Builders & Route Dispatchers**: Allowed up to 20 decision points.

---

## 3. Function Sizing — Cognitive Tiering

Rather than a blunt, naive line cap (which causes destructive slicing), function thresholds are tiered by architectural role:

| Tier | Function Type / Naming Patterns | Comfort Range | Soft Warn | Hard Limit |
|---|---|---|---|---|
| **Standard Logic** | General domain logic, calculations, transformations, algorithms | 20–60 lines | 80 lines | **110 lines** |
| **Declarative Builders / CLI** | `build*`, `init*`, `render*`, `generate*`, `cli*`, `args*`, UI styling | 40–100 lines | 120 lines | **160 lines** |
| **Match & Route Dispatchers** | `handle*`, `dispatch*`, `match_*`, `execute*`, `route*` (arms delegate) | 50–120 lines | 150 lines | **200 lines** |
| **Integration & Unit Tests** | `#[test]`, `#[tokio::test]`, `test_*` assertion sequences & mocks | 50–150 lines | 180 lines | **250 lines** |

> **Strict Project Invariant Note**: Projects with legacy strict caps (e.g. `dider`'s 80-line invariant) should treat **80 lines** as the standard soft warn/gate limit for standard logic, while granting builders, dispatchers, and test functions their respective higher tiers to avoid the "80-line paradox".

---

## 4. Rust Style, Ergonomics & Quality Rules

### Control Flow & "Line of Sight"
- **Left-Aligned Happy Path**: Keep the primary execution path aligned to the left margin. Evaluate pre-conditions, input validation, and boundary conditions first using guard clauses and return early.
- **The Canonical `let-else` Guard**: Prefer `let ... else { return ... };` over nested `if let Some(...) = ...` to extract values and return immediately on failure without rightward drift.
- **Statement-Level `else` Prohibition (`clippy::redundant_else`)**: If an `if` block is in **statement position** and ends with `return`, `continue`, `break`, `panic!`, `bail!`, or `todo!`, an `else` or `else if` block is strictly forbidden. Dedent the subsequent code. (Note: In **expression assignment position**, `let x = if c { a } else { b };` is standard idiomatic Rust).
- **Loop Filtering via `continue`**: Filter collections at the top of `for` loops using `continue` instead of wrapping loop bodies in nested conditionals.

### Error Handling & Propagation
- **The `?` Propagation Operator**: Use the `?` operator for linear, zero-cost error propagation along the happy path.
- **Strict Prohibition of `.unwrap()` and `.expect()` on Fallible Operations**: Never call `.unwrap()` or `.expect()` on I/O, network responses, external commands, filesystem access, user input, or fallible parsers.
- **Permitted Idiomatic Unwraps**:
  1. **Mutex Poisoning**: `mutex.lock().unwrap()` is explicitly permitted; failing on lock poisoning is standard in systems Rust.
  2. **Static Literal Initialization**: Compile-time constant initializers (`LazyLock::new(|| Regex::new("...").unwrap())`) are permitted.
  3. **Verified Mathematical Invariants**: Must include a preceding `// INVARIANT: <explanation>` comment proving why failure is mathematically or structurally impossible.
- **No Silent Error Swallowing**: Never silently swallow errors with bare `.ok()`, `unwrap_or_default()`, or `let _ = ...` without an inline comment explaining why failure is benign.
- **Contextual Error Wrapping**: 
  - Application code: Use `anyhow::Context` (`.with_context(|| format!(...))` or `.context("...")`).
  - Library crates: Use `thiserror` to define strongly-typed, enumerated domain error types.

### Ownership, Borrowing & Memory Ergonomics
- **Borrowing Over Allocation**: Accept borrowed slices (`&str`, `&[T]`) rather than owned collections (`String`, `Vec<T>`) in function arguments unless the function must store or transfer ownership.
- **Differentiate Cheap vs. Pathological Clones**:
  - **Cheap / Idiomatic Clones**: `Arc::clone(&ptr)` ($O(1)$ atomic increment), `Rc::clone`, `Copy` primitives, and small identifiers are fully permitted.
  - **Pathological Borrowck Clones (Strictly Banned)**: Never call `.clone()` or `.to_owned()` on expensive collections (`Vec`, `HashMap`, large AST trees, file payloads) solely to appease the borrow checker during function refactoring. Restructure borrows via view structs or tuple destructuring.
- **Lifetime Hygiene**: Do not introduce generic lifetime parameters (`<'a>`) into application business logic to circumvent borrow-checker errors. Prefer owned data or simple borrowed references; reserve generic lifetimes for zero-copy parsers.

### Testing Strategy
- **Fine-Grained Concurrent Tests**: Unlike Go where table-driven loops are standard, write fine-grained, independent `#[test]` and `#[tokio::test]` functions. `cargo test` executes test cases concurrently across CPU cores; isolated test functions prevent one failing case from masking subsequent test assertions.

### Safety & Unsafe Code
- **Zero Unsafe Tolerance**: Autonomous agents must NEVER introduce `unsafe` blocks without explicit user permission.
- **Mandatory `// SAFETY:` Comment**: Any unavoidable `unsafe` block must be preceded by a comment formatted as `// SAFETY: <proof>` explicitly documenting the invariant that guarantees undefined behavior is impossible.

### Async Hygiene (`tokio`)
- **No Blocking Calls in Async**: Never call synchronous blocking I/O (`std::fs`, `std::thread::sleep`, heavy CPU calculations) inside async tasks. Offload to `tokio::fs` or `tokio::task::spawn_blocking`.
- **No Mutex Guards Across `.await`**: Never hold a `std::sync::MutexGuard` across an `.await` point. Use `tokio::sync::Mutex` if locks must be held across yield points, or restructure the code so the guard is dropped before `.await`.
- **Cancellation Safety**: Ensure state modifications across `.await` points are transactional or cancellation-safe.

### CLI Ergonomics & Anti-Bloat
- **One Canonical Interface**: No hidden commands (`hide = true`), legacy shims, or unadvertised aliases.
- **Concise Help Output**: Short help (`-h`) must fit on a standard 20-line terminal. Extended descriptions belong in long help (`--help`) or an extended info flag (`-E`).

---

## 5. Anti-Decomposition Rules for Agents

When refactoring functions that exceed complexity or line limits, AI agents must follow strict decomposition discipline:

1. **Anti-Clone Slicing**: Never extract a helper function if doing so requires adding `.clone()` or `.to_owned()` to bypass borrow-checker errors on shared state.
2. **View Structs & Partial Borrows**: When a helper requires multiple fields of `self`, pass only the disjoint fields needed (`helper(&mut self.field_a, &self.field_b)`) or bundle related fields into a cohesive sub-struct ("view struct") rather than passing `&mut self`.
3. **No Artificial Continuation Helpers**: Never extract artificial sequential fragments like `process_part_2()`, `handle_step_b()`, or `run_remainder()`. Every extracted helper must represent a single, cohesive, domain-named responsibility (e.g. `parse_header_entry`, `validate_destination_path`, `compute_sha256_digest`).
4. **No Parameter Dumping**: Do not extract a helper if it requires more than 4 parameters or bundling disparate local variables into tuples just to share local state. If state transitions are linear, keep them in place and simplify using guard clauses or table-driven data structures.
5. **Decompose in Place First**: Always decompose oversized functions in place into named private helpers in the same file before moving logical modules into new files. Never split a file across a function body.

---

## 6. File Sizing Guidelines

- **Comfort Metric (300–700 lines)**: Keeping functions under cognitive limits keeps files naturally within the 300–700 line range.
- **Warning Threshold**: 800 lines (soft warning).
- **Hard Limit**: 1100 lines (1600 lines for test files `*_tests.rs` or integration test suites).
- **Module Modularity**: Group modules by cohesive architectural responsibility (e.g. `parser.rs`, `formatter.rs`, `models.rs`, `transport.rs`).

---

## 7. Quality Gates & Multi-Tier Verification

Compliance is automated via a 3-tier milestone verification strategy:

### Tier 1: Fast Quality Gate (`tools/gate` / `rust-audit`)
- Must run in **< 5 seconds**, 100% hermetic and offline.
- Executed on every edit, commit, and version bump.
- Verifies:
  - Formatting: `cargo fmt --check`
  - Linting: `cargo clippy --all-targets -- -D warnings`
  - Sizing & Cognitive Complexity: `rust-audit`
  - Offline Unit Tests: `cargo test`

### Tier 2: Milestone Review & Deep Analysis (`rust-static-analysis` / `tools/benchmark`)
- Executed periodically or automatically on **every 5th version bump**.
- Runs deep analysis:
  - Dependency Vulnerabilities: `cargo audit` (RustSec CVE advisory database)
  - Supply Chain & Licenses: `cargo deny check` (licenses, bans, advisories)
  - Unused Dependencies: `cargo machete` (scans `Cargo.toml`)
  - Unsafe Code Audit: `cargo geiger` (finds and counts `unsafe` usage)
  - Native Performance Benchmark: `./tools/benchmark --rust-only`

### Tier 3: Deep Toolchain & Compiler Integration (`tools/test_deep`)
- Executed automatically on **every 20th version bump** or before major releases.
- Runs heavy integration suites requiring external compilers (`latexmk`, `pdflatex`, `tesseract`, Docker, live network APIs).
