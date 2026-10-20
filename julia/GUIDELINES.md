# AI Agentic Julia Guidelines & Engineering Standards

## 1. Overview & Core Philosophy

This standard establishes architectural principles, cognitive complexity boundaries, and idiomatic Julia conventions for both human engineers and autonomous AI coding agents.

The core objective is **cognitive clarity and correctness**. Lines of code are a secondary proxy; the primary metric is **cognitive complexity** (nesting depth, branch density, and mental state tracking). The limits below are the same as for Ruby, Go, and Rust, so a reviewer moves between languages without recalibrating.

Julia adds one concern the other languages do not have: a function can be correct, short, and simple and still be slow, wrong on some input types, or numerically unstable because of **how the compiler specializes it**. Sections 4 and 5 cover that.

---

## 2. Structural Complexity Limits

### Nesting Depth — Hard Limit 4 (Warn at 3)
- No Julia function may exceed **4 levels of nesting** of `if`, `?:`, `while`, `for`, and closures (`->` and `do` blocks).
- **Resource Block Flattening**: `do` blocks that only manage a resource (`open`, `cd`, `mktempdir`, `mktemp`, `lock`, `withenv`, `redirect_stdout`/`stderr`/`stdin`) provide deterministic cleanup without branching, so they do not add depth.
- `elseif` continues its `if`; it does not add depth.
- A nested named function is measured on its own, not as part of the function that contains it.

### Cognitive Complexity — Hard Limit 15 (Warn at 10)
- A function must not exceed a cognitive complexity of **15**. Each `if`, `?:`, `while`, `for`, and `catch` costs 1 plus its nesting level; each `elseif` costs 1; each run of the same boolean operator (`a && b && c`) costs 1, and switching between `&&` and `||` starts a new run. Comprehension filters cost 1.
- Nested control flow compounds: six nested `if`s cost 1 + 2 + 3 + 4 + 5 + 6 = 21.
- Control jumps, nested branches, and state-dependent logic exceeding the limit must be decomposed into cohesive, domain-named helpers (see section 6).

### Argument Count — Warn Above 5
- More than five positional and keyword arguments is a warning. It usually means the function wants a `struct` (see anti-decomposition rule 2).

---

## 3. Method Sizing — Cognitive Tiering

Length counts **code lines of the body**: blank lines, comment-only lines, the signature (however many lines the formatter gives it), and the closing `end` are excluded. The default JuliaFormatter style spreads long signatures over one argument per line; counting them would punish the formatter's output.

| Tier | Function Type | Comfort Range | Soft Warn | Hard Limit |
|---|---|---|---|---|
| **Standard Logic** | Computations, algorithms, parsers, state transitions | 20–50 lines | 60 lines | **80 lines** |
| **Declarative** | Tables of options, plotting/layout setup, configuration mappings, data construction | 40–90 lines | 100 lines | **120 lines** (if cognitive complexity ≤ 5) |

- Functions over 80 lines up to 120 are permitted only if their cognitive complexity is ≤ 5.
- **Scripts**: single-purpose scripts need no module wrapper; flat top-level code with early `exit` is idiomatic *in scripts*. Limits apply to functions; top-level script code is governed by file limits and nesting depth.
- Test suites are audited with `--include-tests`; `@testset` blocks are not functions, but helper functions in tests are.

---

## 4. Idiomatic Julia Style & Quality Rules

### Formatting
- Use **JuliaFormatter.jl with its default style** (`.JuliaFormatter.toml` containing `style = "default"`, template in [templates/dot_JuliaFormatter.toml](templates/dot_JuliaFormatter.toml)). Do not hand-format and do not customize the style.
- Formatting changes go in **their own commit**, with no logic changes, so that review and `git blame` stay useful. Verify with the project's tests (and any numerical regression snapshot) before committing.

### Control Flow & "Line of Sight"
- **Left-aligned happy path**: validate preconditions first with guard clauses (`isempty(x) && return nothing`, `x > 0 || throw(DomainError(x))`) and return early.
- **Strict ban on `else` after a terminal statement**: if a branch ends in `return`, `break`, `continue`, `throw`, `error`, or `rethrow`, an `else`/`elseif` after it is forbidden; dedent instead.
- Filter loops with `continue` at the top instead of wrapping the body in a conditional.
- **Consistent return types**: every path of a function returns the same *kind* of value. Returning a bare curve on one path and a `(curve, indices)` tuple on another breaks every caller that destructures the result, and it is invisible until that path runs. This is the most common real defect found by static analysis in Julia code.

### Errors and Process Control
- **Throw, do not exit.** Library code (everything under `src/` or inside a module) must signal failure with a typed exception (`ArgumentError`, `DomainError`, `BoundsError`, or a project exception type) and a message that says what was wrong. Never call `exit` or `quit` from library code. Only a script's entry point may exit.
- **Never swallow exceptions.** An empty `catch` hides every failure. Catch the specific expected exception, handle it, and rethrow anything else.
- Use `try ... finally` (or a `do`-block resource function) for cleanup.
- Do not use `@assert` to validate caller input: it states an internal invariant and may be disabled. Use `throw(ArgumentError(...))`.

### Types, Dispatch, and Mutation
- **Dispatch, not type checks**: replace `isa` chains with methods. Annotate arguments only as much as dispatch or correctness needs; do not constrain every argument to a concrete type "for documentation" (it blocks valid inputs such as views and other number types).
- **Struct fields are concretely typed or parametric** (`struct S{T<:Real}; x::T; end`). An untyped field is `Any` and defeats inference; write `::Any` explicitly when that is intended. Prefer `struct` over `mutable struct`.
- **Never commit type piracy**: do not add methods to a function you do not own for types you do not own. Define your own function, or own at least one of the types.
- **Mutation naming**: functions that mutate an argument end in `!`, and the mutated arguments come first. A function either mutates or returns a fresh value, not both.
- **Imports**: use explicit `using Foo: bar, baz` or `import Foo: bar`, placed at the top of the module. Extending another module's function requires `import Foo: f` or `Foo.f(...) = ...`.
- **Globals**: module-level state is `const`. Never use `global` inside a function. Mutable shared state lives in a `struct` or a `const` container (`Ref`, `Dict`).
- Never call `include`, `eval`, or `@eval` from inside a function.

### Performance & Numerical Hygiene
- **Type stability**: a function's return type must be inferable from its argument types. Do not initialize `x = 0` and later assign floats to it; use `x = 0.0` or `zero(T)`. Check suspect functions with `@code_warntype` or JET's `@report_opt`.
- **Containers have concrete element types**: `Vector{Float64}()`, not `[]` or `Vector{Any}()`, unless heterogeneity is the point. Remember that `collect` over an untyped iterator gives `Vector{Any}`.
- Preallocate buffers outside hot loops; use `eachindex` instead of `1:length(x)` (generic indexing), broadcasting with `.=` for in-place updates, and `@views` for slices that are only read.
- `@inbounds` only where bounds are proven by construction, with a comment saying why.
- **`@fastmath` is a semantic change**: it permits reassociation and fused operations, so results can differ by rounding and can depend on inlining. It requires a justification comment on the same line: `# julia-audit: allow-fastmath`, and a test that pins the numerical behavior it is allowed to change.
- **Floating-point comparisons** use a documented tolerance (`isapprox` with explicit `rtol`/`atol`); exact `==` on computed floats needs a comment. Snap-to-endpoint and clamp rules are part of an algorithm's contract: keep them in named functions with tests.

### Julia-Specific Gotchas & Agent Traps
- **Wrong-language style**: translating Python or Java into Julia produces non-idiomatic code: type checks instead of dispatch, validation deferred to the point of use instead of the point where data is loaded, and re-implementing what a package already provides. Check the standard library and the existing packages first.
- **Aliasing**: `y = x` aliases an array; `y = copy(x)` copies; `y .= x` copies into an existing array. Slices copy; views (`@view`) do not. Mutating through an alias is a silent bug.
- **Closures capture variables by reference**: a variable that is reassigned after being captured is boxed (`Core.Box`), is type-unstable, and is shared between tasks. Prefer function arguments or `let` blocks.
- **Global scope is slow and untyped**: loops over non-`const` globals at the top level of a script run orders of magnitude slower. Put work in functions.
- **World age**: code that defines or loads a function and calls it in the same running function needs `Base.invokelatest`. This appears when tools load packages at run time.
- **`NaN`, `missing`, and equality**: `NaN == NaN` is false (`isequal` is true); `missing` propagates through arithmetic and comparisons; `if` on `missing` throws.
- **Implicit `nothing`**: an `if` without `else` as the last expression returns `nothing`. Write the return explicitly.
- **Integer arithmetic wraps**: `Int` overflow is silent. Use `Int128`/`BigInt`, `Base.checked_add`, or `float` where overflow is possible.
- **Strings index by bytes**: `s[i]` throws on a non-character boundary; use `eachindex(s)`, `first`, `chop`, or `collect`.
- **Threads**: `Threads.@threads` over a shared mutable structure is a data race; use per-task buffers or a lock, and guard every read as well as every write.
- **Environment**: do not commit a `Project.toml` with a `[sources]` path that exists on one machine; keep example/benchmark-only dependencies out of the package's runtime dependencies.

---

## 5. Testing & Numerical Regression

- `test/runtests.jl` only includes other test files; each file runs standalone and seeds any random generator it uses.
- Run the package's own quality checks inside the suite: Aqua (`Aqua.test_all`) for ambiguities, piracy, undefined exports, stale dependencies, and compat bounds.
- **Test several element types** for numeric code (`Float32`, `Float64`, and the integer case where it is supported or must be rejected with a clear error).
- **Algorithms need an independent oracle**: compare against a brute-force or textbook implementation on random and degenerate inputs (empty, single point, duplicates, collinear). A function that returns plausible values on typical input can still be wrong on long or degenerate input; tests that only assert "result > 0" do not detect that.
- **Pin refactors with a snapshot**: before any refactor, formatting pass, or dependency swap, record the library's outputs on fixed inputs; afterwards require bit-identical results. A result change must be a separate, deliberate commit.
- Every reported bug gets a minimal regression test (a small fixture file is fine) that fails on the old code.

---

## 6. Anti-Decomposition Rules for Agents

When refactoring functions that exceed complexity or line limits:

1. **No artificial continuation helpers**: never extract `process_part2`, `step_b`, or `run_remainder`. Every helper is one cohesive, domain-named responsibility (`find_prefix`, `clip_to_box`).
2. **No parameter dumping**: do not extract a helper that needs five or more local variables or mutates intermediate state across the boundary. Keep the logic in place and flatten it with guard clauses, or group the state in a `struct`.
3. **Decompose in place first**: split into helper functions in the same file and module before creating new files. Never split a file through a function body.
4. **Do not change numerics while decomposing**: a refactor that reorders floating-point operations, replaces a formula, or changes an early-exit threshold is a behavior change. Prove equality with a snapshot (section 5).

---

## 7. File Sizing

- **Comfort range** 300–700 lines. **Soft warning** at 800. **Hard ceiling** at 1100.
- Exempt: static data/catalog files, with `# julia-audit: allow-long-file` in the file when needed.

---

## 8. Quality Gates and Enforcement Tooling

| Scope | Required validation |
|---|---|
| One standalone script, at most 150 lines, no `Project.toml` | `julia-audit --strict` and `julia-static-analysis <file>` (syntax, formatting). |
| A package or project | Fast gate: strict `julia-audit`, `julia-static-analysis` (syntax, formatting, JET, ExplicitImports), and the test suite, which includes Aqua. |

`julia-audit` measures every function with the parser built into Julia (`Base.JuliaSyntax`, Julia 1.10 or later): nesting depth ≤ 4, cognitive complexity ≤ 15, method length tiers, file size, argument count, and the idiom and trap rules of section 4 that are decidable from syntax:

| Rule | Severity | Meaning |
|---|---|---|
| `else-after-terminal` | warning | `else`/`elseif` after `return`, `break`, `continue`, `throw`, `error`, `rethrow`, or `exit` |
| `argument-count` | warning | more than 5 arguments |
| `untyped-field` | warning | struct field without a type |
| `nonconst-global` | warning | non-`const` module-level assignment in a module |
| `swallowed-exception` | trap | empty `catch` block |
| `exit-in-library` | trap | `exit` called from library code (anything under `src/` or `ext/`, or in a file with a `module`) |
| `global-in-function` | trap | `global` assignment inside a function |
| `runtime-eval` | trap | `eval`, `@eval`, `include`, `include_string`, or `evalfile` inside a function |
| `fastmath` | trap | `@fastmath` without a justification marker |

A warning becomes a failure with `--strict`. Traps always fail. Suppress one on its line with `# julia-audit: allow-<rule>` and a reason; the marker is a promise that someone looked.

`julia-static-analysis` runs `--syntax` (the parser accepts every file), `--format` (JuliaFormatter would not change any file), `--jet` (type-inference analysis of the project's module: method errors, undefined names, inconsistent return types), `--imports` (ExplicitImports: stale imports and imports from non-owner modules must be absent; implicit imports are reported as advisory), and `--aqua`. Default checks: syntax and formatting for single files; those plus JET and imports for a directory inside a project. Missing tools or a failed check exit nonzero. The analysis packages live in one dedicated environment (`~/.julia/environments/standards-julia`, or `JULIA_STANDARDS_ENV`), created only by `julia-install-tools`; gates never install anything.

JET needs the project to load (`Pkg.instantiate()` done) and can report false positives; fix real findings, and for a justified false positive prefer restructuring the code so that the return type is concrete over suppressing the report.

Copy `templates/dot_JuliaFormatter.toml` as the project's `.JuliaFormatter.toml` and add the snippet in [templates/AGENTS_SNIPPET.md](templates/AGENTS_SNIPPET.md) to the project's agent instructions. Lifecycle helpers (`tools/build`, `tools/gate`, `tools/commit`, `tools/bump`, …) for Julia are not provided yet; run the commands above directly.
