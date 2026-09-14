# Philosophy & Rationale: AI Agentic Go Engineering Standards

## 1. Why Written Rationale Matters

Software engineering rules written without their underlying rationale inevitably degrade into cargo-cult constraints. Developers and AI agents alike begin treating numbers as arbitrary obstacles to be gamed rather than principles designed to maximize software reliability and maintainability.

This document records the empirical reasoning, cognitive science foundations, and AI failure modes that shaped the standards in `GUIDELINES.md`.

---

## 2. The 80-Line Paradox: Why Naive Line Limits Fail

A naive, universal rule such as *"no function may exceed 80 lines"* produces severe pathological behavior in Go codebases, particularly when refactored by AI agents:

### The Pathology of Blind Slicing
When a 115-line function exceeds an arbitrary line cap, an automated agent or uncritical engineer typically reacts by chopping the function across the middle:
- Extracting `processStep2()` or `handleSecondHalf()`.
- Passing 5 or 6 pointers to local variables just to pass mutable state across the artificial boundary.
- Scattering linear logic across disparate scopes, increasing cognitive stack depth.

### The True Cost
The resulting refactored code has technically fewer lines per function, but is **substantially harder to understand, debug, and maintain**. The reader must constantly jump between functions to piece together a single linear execution thread.

### The Resolution: Lines as a Proxy, Cognitive Complexity as the Metric
Lines of code are not the root problem. **Unmanaged mental state is the root problem.** A 120-line linear struct builder with zero branches is trivial to verify. Conversely, a 45-line function with 5 nested `if/for` blocks and 18 branches is an incomprehensible bug incubator.

Therefore, our guidelines treat lines of code as a **tiered upper bound**, while treating **nesting depth ($\le 4$)** and **branch points ($\le 15$)** as the primary correctness boundaries.

---

## 3. Cognitive Load Theory & Tiering Rationale

Human working memory can actively manage $7 \pm 2$ distinct chunks of information simultaneously (Miller's Law). When reading source code, each nested block and each conditional branch pushes a new mental frame onto the reader's cognitive stack.

### Tier 1: Standard Logic Functions (Hard Limit: 110 lines, Branches: $\le 15$)
- Standard business logic mixes control flow, data transformations, error checking, and mutations.
- At 110 lines, if written with early returns, a function typically contains 3–5 distinct logical steps. Beyond 110 lines, the number of interacting variables exceeds reliable working memory.

### Tier 2: Declarative Builders & UI Layouts (Hard Limit: 160 lines, Branches: $\le 20$)
- Functions that instantiate models, construct terminal UI layouts (e.g. Bubble Tea / Lipgloss), or define declarative specifications often require many vertical lines of struct literals, styling definitions, and layout assembly.
- Because these functions are largely linear and declarative (branching depth $\le 2$), their cognitive density is low. Forcing them to be split into fragments destroys the visual representation of the UI layout.

### Tier 3: Event & Key Dispatchers (Hard Limit: 200 lines, Branches: $\le 20$)
- In terminal applications, event dispatchers (e.g. `handleKey`) route dozens of keyboard shortcuts or message types.
- When written as flat `switch` blocks where each `case` delegates immediately to a dedicated named helper, the cognitive load of the dispatcher is virtually zero—it is a lookup table.
- Imposing an 80-line limit on dispatchers forces artificial hierarchy (dispatchers dispatching to sub-dispatchers), making key mapping discovery cumbersome.

### Tier 4: Table-Driven Tests (Hard Limit: 250 lines)
- Idiomatic Go tests declare slices of anonymous structs containing test cases, inputs, and expected outputs, followed by a simple execution loop.
- A comprehensive test suite for a tricky parser may require 15–20 test cases spanning 200 lines. Arbitrarily splitting test tables across multiple helper functions decreases test visibility and adds boilerplate.

---

## 4. Google Go Style: Line of Sight & Guard Clauses

The official Google Go Style Guide mandates a principle known as **"Line of Sight"**:
> *"Keep the primary execution path aligned to the left margin."*

### Why We Strictly Ban `else` After Terminal Statements
Consider this common anti-pattern:
```go
// BAD: Deeply nested, rightward drift, multiple exit points to track
if condition {
    // ...
    return val
} else {
    // ...
    return otherVal
}
```
When an `if` branch terminates the execution flow via `return`, `continue`, `break`, or `panic`, an `else` block serves zero logical purpose. It introduces unnecessary visual nesting and forces the reader to track two parallel execution branches in their head.

By strictly banning `else` after terminal statements, the happy path remains un-indented at the left margin:
```go
// GOOD: Left-aligned happy path, zero nested mental stack
if condition {
    return val
}

// Left-aligned primary path continues here...
return otherVal
```

### Why Guard Clauses Eliminate Nesting
Instead of wrapping the entire function body in a validation check:
```go
// BAD: Everything indented one level
if token != "" {
    if fileExists(path) {
        // 50 lines of logic here
    }
}
```
We evaluate preconditions first and return immediately:
```go
// GOOD: Nesting depth is 0
if token == "" || !fileExists(path) {
    return
}
// 50 lines of logic here
```
This single habit systematically eliminates 60–80% of nesting depth violations across codebases.

---

## 5. Anti-Decomposition Rules for Autonomous Agents

Autonomous coding agents (LLMs) have a specific vulnerability: when faced with a strict linter error, they prefer the path of least resistance to make the linter exit with code 0.

Without anti-decomposition constraints, agents generate:
1. **Artificial Continuation Helpers**: Naming functions `stepPart1`, `stepPart2`, `doPhaseB`. These names convey zero domain semantics and make stack traces uninformative.
2. **Parameter Dumping**: Extracting a helper that takes 7 arguments just because those 7 local variables were in scope. This increases coupling and makes functions fragile.

### The Rule of Domain Cohesiveness
Every extracted helper must have a **single, cohesive, domain-named responsibility**. If you cannot name the function with a clear domain action (e.g. `parseCachedCalendar`, `combineEventFields`, `filterExistingEvents`), the code is not a cohesive unit and should not be extracted as an isolated function.

---

## 6. Two-Tier Static Analysis Philosophy

Static analysis tools are not all equal in cost or intent:

### Tier 1: Continuous & Pre-Commit (`go-audit`, `go vet`, `staticcheck`)
- Must run in $\le 2$ seconds.
- Detects objective compiler violations, formatting drift, and sizing/complexity boundaries.
- Designed to run on every file save and every working git commit.

### Tier 2: Deep Periodic Review (`go-static-analysis`)
- Deploys heavy AST heuristic engines: `gocritic`, `revive`, `shadow`, `dupl`, and `govulncheck`.
- Runs in 4–8 seconds.
- These tools produce qualitative and heuristic findings. Some clone groups (`dupl`) in CLI options or table declarations are intentional; others point to real copy-paste bugs.
- Running them periodically ensures the codebase stays free of subtle architectural debt without bogging down rapid commit cycles.
