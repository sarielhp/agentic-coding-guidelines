# Philosophy & Rationale: AI Agentic Rust Engineering Standards

## 1. Why Written Rationale Matters

Software engineering rules written without their underlying rationale inevitably degrade into cargo-cult constraints. Developers and AI agents alike begin treating numbers as arbitrary obstacles to be gamed rather than principles designed to maximize software reliability, memory safety, and maintainability.

This document records the empirical reasoning, cognitive science foundations, and AI failure modes that shaped the standards in `GUIDELINES.md`.

---

## 2. The 80-Line Paradox in Rust: Why Naive Line Limits Fail

In Go, imposing a blunt 80-line cap causes agents to slice functions across the middle and pass pointers to local variables. In **Rust**, however, a naive 80-line cap is vastly more destructive due to the **Borrow Checker**.

### The Pathology of Borrowck Panic Slicing
When a 115-line Rust function exceeds an arbitrary line limit, an automated AI agent attempts to extract lines 60–115 into a helper function `process_step_2()`. Immediately, the Rust compiler strikes back:
1. **Partial Borrow Conflicts**: The parent function holds a mutable reference `&mut self.field_a` while the extracted helper needs access to `self.field_b`. Passing `&mut self` to the helper causes an immediate borrow checker violation: *"cannot borrow `*self` as mutable more than once at a time"*.
2. **The Agent's Desperate Workarounds**:
   - **The Clone Escape Hatch**: The agent inserts `.clone()` on `Vec`, `String`, or large structs to eliminate the borrow conflict. Performance plummets by orders of magnitude.
   - **The Synchronization Escape Hatch**: The agent wraps fields in `Arc<Mutex<T>>` or `Rc<RefCell<T>>` just to bypass compile-time borrowing rules.
   - **The Lifetime Nightmare**: The agent attempts to annotate the helper with multiple lifetime parameters (`<'a, 'b: 'a>`), introducing viral lifetime complexity that pollutes public interfaces.

### The True Cost
The resulting refactored code has technically fewer lines per function, but it is **catastrophically worse**:
- It introduces severe memory allocation overhead.
- It hides data flow behind artificial pointer wrappers or clone chains.
- It is fragile and difficult for subsequent agents to reason about without causing lifetime cascades.

### The Resolution: Lines as a Proxy, Cognitive Complexity as the Metric
Lines of code are not the root problem. **Unmanaged mental state and borrow complexity are the root problems.** 
A 130-line linear struct builder or CLI subcommand parser with zero nested branches and no shared mutable borrows is trivial to verify. Conversely, a 45-line function with 4 nested `match` blocks, raw pointer manipulations, and tricky lifetimes is a bug incubator.

Therefore, our guidelines treat lines of code as a **tiered upper bound**, while treating **nesting depth ($\le 4$)** and **branch points ($\le 15$)** as the primary correctness boundaries.

---

## 3. Rust vs. Go: Fundamental Architectural Divergences

Rust and Go share a commitment to software reliability, but their language mechanics diverge fundamentally. Rules developed for Go must be thoughtfully adapted to Rust:

### 1. Expressions vs Statements: Pattern Matching & `let-else`
- **Go**: Statement-oriented. Early returns require explicit 3-line `if` checks (`if err != nil { return nil, err }`).
- **Rust**: Expression-oriented.
  - Rust features **exhaustive pattern matching (`match`)**. In CLI dispatchers or AST parsers, matching on an enum with 20 variants is idiomatic and clean. Counting every flat arm as an independent decision point would falsely penalize idiomatic code. Hence, our **Flat Match Exemption** counts a flat dispatching `match` as 1 decision point.
  - The **`let-else` guard** (`let Some(val) = opt else { return ... };`) provides the cleanest possible left-aligned extraction. Unlike Go, where extracting a value often requires temporary variables and separate checks, `let-else` combines destructuring, pattern validation, and divergence into a single statement without rightward drift.

### 2. The `?` Operator vs Explicit `if err != nil`
- **Go**: Error checking produces vertical line bloat. A 100-line Go function often contains 40 lines of `if err != nil` checks.
- **Rust**: The `?` operator compresses error propagation into a single character. This keeps the happy path left-aligned and concise.
- **The Agent Failure Mode in Rust**: Because `?` requires compatible error types, agents frequently take shortcuts:
  - Calling `.unwrap()` or `.expect()`, leading to runtime panics in production.
  - Calling `.ok()` or `.unwrap_or_default()`, silently swallowing network errors or parsing corruptions.
  - Therefore, Rust standards must be significantly stricter regarding `.unwrap()` and error swallowing than Go standards.

### 3. Ownership & Borrowing vs Garbage Collection
- **Go**: The runtime garbage collector frees developers from thinking about lifetimes. Functions can freely return pointers to local variables (which escape to the heap).
- **Rust**: The compiler enforces affine types and strict single-owner semantics at compile time. 
- **Decomposition Constraint**: In Go, decomposing a function is purely a control-flow exercise. In Rust, decomposing a function is an **architectural data-flow exercise**. Agents must be constrained against adding `.clone()` to resolve borrow check failures during decomposition.

### 4. Cooperative Async (`tokio`) vs Preemptive Goroutines
- **Go**: Goroutines are preemptive. Developers rarely worry about blocking the thread pool or holding locks across channel operations.
- **Rust**: Async functions are state machines polled cooperatively by an executor (`tokio`).
  - Holding a synchronous `std::sync::MutexGuard` across an `.await` point will cause thread starvation or deadlock.
  - Executing synchronous blocking I/O (`std::fs`, `std::thread::sleep`) inside an async task blocks the entire OS worker thread.
  - Futures can be dropped at any `.await` point (cancellation hazards), potentially corrupting multi-step state mutations.

### 5. The Safety Boundary (`unsafe`)
- **Go**: Memory safety is implicit across virtually the entire language.
- **Rust**: `unsafe` creates a boundary where the compiler disables borrow and pointer checks. AI agents are notoriously prone to introducing subtle undefined behavior (data races, unaligned pointers, use-after-free) when writing `unsafe`. Autonomous agents must be strictly forbidden from introducing `unsafe` code.

---

## 4. Cognitive Load Theory & Tiering Rationale for Rust

Human working memory manages $7 \pm 2$ items simultaneously (Miller's Law). When reading source code, each nested block, lifetime scope, and conditional branch pushes a new mental frame onto the reader's cognitive stack.

### Tier 1: Standard Logic Functions (Hard Limit: 110 lines, Branches: $\le 15$)
- Mixes transformations, validations, and mutations.
- Beyond 110 lines with multiple borrow scopes, tracking which variables are borrowed, moved, or dropped exceeds reliable cognitive capacity.
- *Strict project note*: In codebases like `dider` enforcing an 80-line ceiling, 80 lines serves as the soft warning threshold to keep logic compact.

### Tier 2: Declarative Builders & CLI Layouts (Hard Limit: 160 lines, Branches: $\le 20$)
- Struct instantiation, builder method chains (e.g. `clap::Command::new()`, `reqwest::ClientBuilder`), and UI styling layouts.
- Because these methods have linear data flow (nesting depth $\le 2$), their cognitive complexity is low. Splitting them into arbitrary fragments destroys visual hierarchy.

### Tier 3: Match & Route Dispatchers (Hard Limit: 200 lines, Branches: $\le 20$)
- CLI subcommand routers and event handlers.
- When written as flat `match` blocks where each arm delegates directly to a named helper function, the dispatcher acts as an indexed lookup table. Cognitive density is zero.

### Tier 4: Integration & Unit Tests (Hard Limit: 250 lines)
- Rust `#[test]` functions that initialize test databases, construct complex mock payloads, execute commands, and run assertions.
- Splitting cohesive test cases across multiple test helpers obscures the test narrative and hides assertion failures.

---

## 5. Anti-Decomposition Traps in Autonomous Agents

Autonomous agents optimize for linter exit code 0. In Rust, this tendency triggers specific anti-patterns:

1. **Trap 1: The "Clone Everything" Escape Hatch**: When borrowck complains about a shared reference across an extracted helper, the agent calls `.clone()`. We strictly forbid this: if a helper cannot borrow data naturally, pass specific sub-fields or restructure the data model.
2. **Trap 2: The `Arc<Mutex<T>>` Escalation**: Wrapping internal state in synchronization primitives just to appease compiler warnings about shared mutability in single-threaded logic.
3. **Trap 3: The `.ok()` and `unwrap_or_default()` Silent Swallower**: When a function's return type is not a `Result`, the agent turns `fallible_op()?` into `fallible_op().ok()` to avoid changing the function signature, silently dropping critical error context.
4. **Trap 4: The 15-Combinator Iterator Monster**: Stringing together endless `.filter().map().flat_map().try_fold()` chains with nested closures to look "idiomatic". Beyond 3 combinators, prefer an explicit loop with guard clauses or intermediate named collections.

---

## 6. The 3-Tier Quality & Milestone Strategy (from `dider`)

Static analysis and test suites have varying runtimes and scopes. Following the battle-tested model in `dider`:

- **Tier 1: Fast Quality Gate (`tools/gate` / `rust-audit`)**: Under 5 seconds. Checks formatting (`cargo fmt`), compiler lints (`cargo clippy`), cognitive sizing (`rust-audit`), and hermetic offline tests (`cargo test`). Runs on every edit and commit.
- **Tier 2: Milestone Review & Benchmark (`rust-static-analysis` / `tools/benchmark`)**: Runs on every 5th bump. Checks dependency vulnerabilities (`cargo audit`), license/bans (`cargo deny`), unused crates (`cargo machete`), and native benchmarks.
- **Tier 3: Deep Toolchain Integration (`tools/test_deep`)**: Runs on every 20th bump. Checks external compiler pipelines (`latexmk`, `pdflatex`, `tesseract`, network APIs) without slowing daily velocity.
