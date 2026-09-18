# Architectural & Cognitive Rationale: Ruby Standards

This document establishes the empirical, cognitive, and systems rationale behind the rules in [`GUIDELINES.md`](GUIDELINES.md).

---

## 1. The Core Problem: The AI Refactoring Trap in Ruby

When autonomous coding agents are instructed using crude, blanket rules like *"keep methods under 15 lines"* (the default in tools like RuboCop), they optimize mechanically for the line metric rather than structural clarity.

In Ruby, this produces well-documented pathologies:

1. **Artificial Continuation Slicing**: An agent divides a cohesive 35-line algorithm into meaningless fragments:
   ```ruby
   # Pathological AI decomposition:
   def process_payload(data)
     validate_payload(data)
     process_payload_part1(data)
     process_payload_part2(data)
   end
   ```
   Neither `part1` nor `part2` represents a cohesive domain concept. Readers and agents alike must mentally reconstruct the fragmented control flow.

2. **Parameter & State Dumping**: Because Ruby uses lexical variable scoping, splitting a method forces the agent to pass mutable hashes, intermediate arrays, or instance variables across artificial boundaries:
   ```ruby
   # Pathological state dumping:
   process_step_b(data, temp_buf, flags, status, options, cache)
   ```

3. **Silent Exception Masking**: When agents scatter linear logic across several helper methods, they frequently introduce defensive exception handlers like `rescue nil` or `rescue Exception` to suppress errors caused by partial state transitions, destroying observability.

---

## 2. Cognitive Load Foundations

The human and LLM working memory is strictly limited ($7 \pm 2$ chunks, Miller's Law). Code readability is not a function of vertical whitespace; it is a function of **state tracking overhead**:

### A. Nesting Depth ($\le 4$)
Each nested block (`if`, `while`, `case`) introduces an active precondition that must be retained in working memory. At depth 5, the reader must track 5 simultaneous conditional states to understand a single expression.

### B. Cognitive Complexity ($\le 15$)
Unlike cyclomatic complexity (which simply counts branches), cognitive complexity accounts for nesting penalties:
- A flat `case` statement with 6 branches has a cognitive complexity of 1 (a single decision table).
- Six nested `if` statements have a cognitive complexity of $1 + 2 + 3 + 4 + 5 + 6 = 21$.

### C. Resource Block Flattening
Idiomatic Ruby relies heavily on block-scoped resource management:
```ruby
Dir.chdir(build_dir) do
  File.open(output_file, 'w') do |f|
    f.write(content)
  end
end
```
While technically two nested blocks, this construct introduces **zero branching decisions**. The cognitive load is flat. Treating resource management blocks as decision nesting would penalize safe, deterministic cleanup.

---

## 3. Tiered Sizing Justification (Ruby vs. Go)

Why does Ruby use an **80-line limit** for logic while Go uses **110 lines**?

1. **Syntactic Density**: Ruby is extraordinarily expressive. A single line of Ruby enumerable processing (`items.group_by(&:category).transform_values(&:count)`) represents 8–12 lines of explicit loop and map manipulation in Go. An 80-line Ruby method contains significantly more operational logic than an 80-line Go function.
2. **Declarative Ceiling (120 lines)**: Command-line interface definitions (`OptionParser.new do |opts| ... end`), JSON schema mappings, and routing tables consist of flat, repetitive declarations. Forcing artificial slicing of an `OptionParser` block because it reaches 85 lines harms cohesion. Thus, methods with Cognitive Complexity $\le 5$ are granted an extended ceiling of 120 lines.

---

## 4. Systems & Runtime Invariants

### A. The Fatal Danger of `rescue Exception`
In Ruby, `Exception` is the root of the entire exception hierarchy:
```text
Exception
 ├── NoMemoryError
 ├── SignalException
 │    └── Interrupt (SIGINT / Ctrl-C)
 ├── ScriptError
 │    └── SyntaxError
 ├── SystemExit (exit called)
 └── StandardError  <-- Application errors belong here!
      ├── ArgumentError
      ├── RuntimeError
      └── ...
```
Rescuing `Exception` traps `Interrupt` (preventing users from interrupting execution with `Ctrl-C`) and `SystemExit` (preventing subcommands from terminating with appropriate exit codes). Application code must always rescue `StandardError`.

### B. The Anti-Pattern of `rescue nil`
Writing `foo.bar rescue nil` swallows `NoMethodError`, typos in variable names, syntax issues, and critical operational failures without leaving a trace. If an expression can legitimately fail, catch the specific expected error and provide an explicit fallback.

### C. String Allocation Churn & Garbage Collection
Ruby strings are mutable objects by default. In hot loops or large parsers:
- `str += chunk` allocates a new string object and copies existing bytes on every iteration, triggering frequent GC pauses.
- `str << chunk` mutates the existing buffer in-place without heap reallocations.
- `# frozen_string_literal: true` ensures identical string literals share a single deduplicated object across the entire runtime.

### D. Block Control-Flow Boundaries: Non-Local Jumps
In Ruby, blocks are closures that retain lexical binding to their enclosing method:
- Executing `return` inside an enumerable block (`items.each { |x| return if x.done? }`) does **not** return from the block—it executes a **non-local jump**, immediately terminating the enclosing method!
- If the block is stored in a Proc and executed after the enclosing method has already returned, it raises `LocalJumpError: unexpected return`.
- Using `next` properly returns a value from the block scope (behaving like `continue` in a loop).
- `lambda` enforces arity checks and treats `return` locally, whereas `Proc.new` permits non-local jumps and lenient arity. Agents must never substitute `return` for `next` inside iterators.

### E. Truthiness: The Semantic Divergence from Python and JavaScript
In Python and JavaScript, `0`, `""`, and `[]` are falsy. In Ruby, **only `nil` and `false` are falsy**.
When an agent writes `process(data) if data`, it expects `[]` or `{}` to bypass execution. In Ruby, empty collections evaluate to `true`, causing runtime operations on empty structures or silent logic corruption. Explicit presence checks (`.any?`, `!empty?`, `.positive?`) are required.

### F. Hash Default Value Mutation Hazard
Writing `Hash.new([])` passes an object reference. Ruby does not instantiate a new array for each missing key; it returns that exact same array reference for every missing key. When code mutates it via `hash[key] << item`, it mutates the shared default object. The block form `Hash.new { |h, k| h[k] = [] }` guarantees dynamic per-key instantiation.

### G. Metaprogramming & Monkey Patching Invisibility
While reopening classes (`class String; ... end`) is a hallmark of Ruby flexibility, in autonomous agent workflows it is toxic:
1. **AST Invisibility**: Static analysis tools (`ruby-audit`, `rubocop`) cannot reliably trace dynamic monkey patches or `class_eval` definitions across separate files.
2. **Action at a Distance**: Reopening core classes pollutes all dependencies and gems loaded in the VM process.
3. **Refinements as the Safe Alternative**: If custom syntax convenience is needed, Refinements (`refine` / `using`) restrict modifications strictly to the lexical file scope where they are activated.

---

## 5. Summary Matrix: Anti-Decomposition & Ruby Trap Rules

| Anti-Pattern | Why Agents Do It | The Mandated Solution |
|---|---|---|
| **Sequential Slicing** (`part_1`, `part_2`) | Blindly trying to satisfy line limits | Use guard clauses to flatten happy path; keep cohesive logic intact up to 80 lines. |
| **Parameter Dumping** ($>4$ arguments) | Slicing methods with shared local state | Keep logic unified or extract an immutable value object/struct. |
| **`rescue nil` Shielding** | Masking state bugs introduced by decomposition | Remove artificial boundaries; allow invariants to fail fast with descriptive messages. |
| **`rescue Exception`** | Catching "everything" defensively | Rescue only `StandardError`; permit signals and process exits to propagate cleanly. |
| **Non-Local `return` in Blocks** | Treating blocks like Python/JS loop bodies | Use `next` to skip iterations; reserve `return` strictly for method-level early exits. |
| **Truthiness Punning (`if items`)** | Assuming empty collection/0 is falsy | Use explicit predicates (`items.any?`, `count.positive?`). |
| **`Hash.new([])` Mutation** | Unaware of shared reference binding | Use block constructor: `Hash.new { |h, k| h[k] = [] }`. |
| **Global Core Monkey Patching** | Adding quick string/array convenience helpers | Encapsulate in utility modules (`StringUtils`) or use file-scoped Refinements. |
| **String Key vs Symbol Miss** | Mixing up hash key representations | Standardize keys at parsing (`symbolize_names: true`) and use `.fetch(:key)`. |
