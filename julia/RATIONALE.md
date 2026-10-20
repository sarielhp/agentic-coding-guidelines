# Architectural & Cognitive Rationale: Julia Standards

This document records the reasoning behind the rules in [`GUIDELINES.md`](GUIDELINES.md), and the evidence from real code that motivated the Julia-specific ones.

---

## 1. The Core Problem: The AI Refactoring Trap in Julia

The general failure modes (slicing a coherent algorithm into `part1`/`part2`, dumping state through long parameter lists, masking the resulting errors) apply in Julia as they do elsewhere. Reports from Julia users working with coding agents add language-specific ones:

1. **Translated, non-idiomatic style.** Agents write Julia that reads like Python or JavaScript: type checks instead of multiple dispatch, validation postponed to where a value is consumed instead of where it is loaded (duplicating checks across functions), and re-implementation of what the standard library or an existing package already provides.
2. **Over-annotation.** Agents constrain every argument to a concrete type "for clarity", which blocks views, other number types, and generic code.
3. **Wasteful allocation.** For example, allocating a whole array just to add one to its first element.
4. **Environment churn.** Agents restart Julia constantly and make environment-setup mistakes; Julia's startup and compilation cost makes that expensive.

Community practice against these is mostly lightweight: a short instruction file targeting the few most annoying habits, review of small chunks, hooks that reject patterns, tests against reference implementations, and a CI "ratchet" that tracks complexity, static analysis, coverage, and file size. These standards follow the same direction but make the limits measurable.

---

## 2. Cognitive Load Foundations

The measures are the ones used for Ruby, Go, and Rust, so a reviewer moves between languages without recalibration.

### A. Nesting depth (≤ 4)
Each nested `if`, loop, or closure adds a precondition the reader must hold. At depth 5 a reader tracks five simultaneous conditions.

### B. Cognitive complexity (≤ 15)
Cyclomatic complexity counts branches; cognitive complexity also charges nesting. A flat run of six `elseif` branches is a decision table (cost 6); six *nested* `if`s cost 21. `julia-audit` counts, per function:

- `if`, `?:`, `while`, `for`, `catch`: 1 + nesting level;
- `elseif`: 1, without extra nesting (it continues its `if`);
- a run of the same boolean operator: 1 (so `a && b && c` costs 1, and `a && b || c && d` costs 3);
- comprehension filters: 1.

Depth increases for `if`, `?:`, `while`, `for`, `->`, and `do` blocks, except `do` blocks that only manage a resource.

**Cross-check.** The same counting model was compared with CodeComplexity.jl's cognitive complexity on FrechetDist's source. Values agreed exactly for several functions (42 for `frechet_c_compute`, 22 for `compute_leash_from_arr`) and within a few points for others (52 versus 54 for `frechet_c_approx`; differences come from comprehension and operator-run rules), and both put the same functions at the top.

### C. Resource block flattening
`open(path) do io ... end`, `cd(dir) do ... end`, `lock(l) do ... end`, and `mktempdir() do ... end` introduce no decisions; counting them as nesting would penalize safe, deterministic cleanup.

### D. Closures count
`map(x -> ..., v)` and `do` blocks with logic hide a function body inside an expression. They add depth, and the variables they capture are shared by reference (see section 4D).

---

## 3. Tiered Sizing Justification

- **80 lines for logic, 120 for declarative code**, as in Ruby: Julia is about as dense, with broadcasting and comprehensions replacing explicit loops.
- **Body lines only.** The default JuliaFormatter style puts a long signature on one line per argument. A function with eight arguments then has a ten-line signature that carries no logic. Counting only body code lines (excluding the signature, blanks, comments, and the closing `end`) keeps the measure about logic, so formatting cannot change whether code passes.
- **Argument count.** Julia code with keyword arguments grows long signatures easily. More than five is a warning because it correlates with parameter dumping.

---

## 4. Systems & Runtime Invariants

### A. Inconsistent return types are the most common real defect
Static analysis (JET) on a mature, tested 7000-line Julia library found, as its only real bugs, two functions that returned a bare value on the empty-input path and a `(value, indices)` tuple otherwise. Every caller destructures the tuple, so the empty path would have crashed with an unrelated-looking error. The tests never exercised it. Hence the rule that every path returns the same kind of value, and why JET is in the gate.

### B. Type stability and abstract containers
Julia compiles a specialized version of each function per argument-type combination. If the result type cannot be inferred (`x = 0` later assigned a float; a container of `Any`; an abstractly typed struct field), the specialization falls back to dynamic dispatch, often 10–100 times slower, with no error. Concrete struct fields, concrete container element types, and `zero(T)`-style initialization are the cheap defenses; `@code_warntype` and JET's `@report_opt` find the rest.

### C. `exit` in library code
`exit` in a library kills the caller's process, including a user's REPL session, a test run, or a server, and gives it no chance to handle the failure. A library throws; only a program's entry point exits. A mature Julia library audited while writing these standards had five such calls in algorithm code; `julia-audit` flags them (`exit-in-library`).

### D. Closures, boxing, and globals
A variable captured by a closure and reassigned afterwards is boxed (`Core.Box`), which makes it type-unstable and shared across tasks. Top-level loops over non-`const` globals run without type information. Both fail silently and slowly, which is why they are guideline rules and not lint warnings.

### E. `@fastmath`, floating-point, and refactoring safety
`@fastmath` allows reassociation and contraction into fused multiply-add, and the compiler's choice can depend on the surrounding code after inlining. In a geometric library, a `@fastmath` distance accumulation over four coordinates differed in the last bit from the plain `sum(abs2, p - q)`; in two or three dimensions the two agreed on millions of random pairs. A migration to a shared geometry package therefore kept local copies of the primitives to remain bit-identical, and one four-dimensional output still differed by about one unit in the last place, depending on inlining context.

Lessons that became rules: `@fastmath` requires a justification marker and a pinning test; floating-point snapping and clamping rules are part of an algorithm's contract and belong in named, tested functions; and **any refactor must be proven with a snapshot of outputs**, not just a passing test suite. A shared library's `convex_comb` that did not snap to endpoints within 1e-6 changed which of several equal-cost morphings an algorithm produced, even though every leash was identical.

### F. Why algorithms need an independent oracle
A published bug report showed a Fréchet distance routine returning values up to 0.1% too large on long, nearly collinear GPS tracks: valid upper bounds, so tests that only check plausibility pass. It failed on inputs of about 100 vertices. A regression test comparing the routine against a second, independent computation of the same quantity (a tighter approximation, a brute-force oracle, or a decision procedure) on a small fixture catches it; random walks of 3–60 vertices, which the report notes did not trigger it, would not.

### G. World age
Calling a function defined at run time from the code that defined it fails with a "method too new" error unless it goes through `Base.invokelatest`. Tooling that loads packages dynamically (analysis runners, plugin loaders) hits this; it is the reason `julia-checks.jl` wraps the calls.

### H. `@assert` and exceptions
`@assert` documents an internal invariant and its behavior is not guaranteed for validation. Caller mistakes get typed exceptions (`ArgumentError`, `DomainError`) with a message, so failures can be handled and tested.

---

## 5. Tool Choices

| Tool | Used for | Notes |
|---|---|---|
| `Base.JuliaSyntax` | all `julia-audit` metrics and rules | ships inside Julia ≥ 1.10: no dependency, exact line ranges |
| JuliaFormatter.jl | formatting, default style | the standard formatter; default style chosen to avoid configuration drift; a check mode lets gates fail on drift |
| JET.jl | `--jet` | type-inference analysis: method errors, undefined names, inconsistent returns. Tied to the compiler version, so results can vary between Julia releases, and it can report false positives |
| ExplicitImports.jl | `--imports` | stale imports, non-owner imports; implicit-import and non-public-import findings are advisory |
| Aqua.jl | `--aqua` and the project's tests | ambiguities, piracy, undefined exports, stale dependencies, compat bounds |

Considered and not required: CodeComplexity.jl (a young package providing cyclomatic/cognitive/argument metrics, used here only as a cross-check; the in-repo auditor needs no dependency and also measures depth and length), StaticLint.jl (editor-oriented), ReLint.jl (promising, not yet evaluated), and Runic.jl (an alternative opinionated formatter).

---

## 6. Summary Matrix: Anti-Decomposition & Julia Trap Rules

| Anti-pattern | Why agents do it | The mandated solution |
|---|---|---|
| Sequential slicing (`part_1`, `part_2`) | satisfying a line limit mechanically | guard clauses; keep cohesive logic intact up to 80 lines |
| Parameter dumping (> 4 arguments) | splitting a function with shared locals | keep unified, or group state in a `struct` |
| Different return shapes per path | early exits written independently | one return kind; destructure-safe results |
| `catch` with an empty body | silencing errors caused by partial state | catch the specific exception; handle or rethrow |
| `exit` in library code | copying script patterns | throw a typed exception |
| Over-annotated arguments | "documenting" types | annotate for dispatch/correctness only |
| Untyped fields / `Vector{Any}` | unspecified intent | concrete or parametric types |
| `global` in functions, non-`const` globals | quick shared state | `const` containers or a `struct` |
| `@fastmath` for speed | cargo-culted optimization | justify, pin with a test, prove with a snapshot |
| Numerics changed during a refactor | "equivalent" rewrites | snapshot equality; behavior changes are separate commits |
| Wrong-language idioms | translating Python/Java | dispatch, existing packages, generic indexing |

---

## 7. Sources

- Julia Discourse: [Best Practices for Using Coding Agents with Julia?](https://discourse.julialang.org/t/best-practices-for-using-coding-agents-with-julia/136829), [Idiomatic Julia code in AI generated code](https://discourse.julialang.org/t/idiomatic-julia-code-in-ai-generated-code/139183), [Is there a ruff like linter](https://discourse.julialang.org/t/is-there-a-ruff-like-linter/130871)
- [SciML Style Guide](https://docs.sciml.ai/SciMLStyle/stable) (style, type piracy, mutation naming, imports, tests)
- [Modern Julia Workflows: optimizing](https://modernjuliaworkflows.org/optimizing/) (type stability tooling)
- [CodeComplexity.jl](https://github.com/charleskawczynski/CodeComplexity.jl), [JET.jl](https://github.com/aviatesk/JET.jl), [ExplicitImports.jl](https://github.com/JuliaTesting/ExplicitImports.jl), [Aqua.jl](https://github.com/JuliaTesting/Aqua.jl), [JuliaFormatter.jl](https://github.com/domluna/JuliaFormatter.jl)
