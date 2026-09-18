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

---

## 5. Summary Matrix: Anti-Decomposition Rules

| Anti-Pattern | Why Agents Do It | The Mandated Solution |
|---|---|---|
| **Sequential Slicing** (`part_1`, `part_2`) | Blindly trying to satisfy line limits | Use guard clauses to flatten happy path; keep cohesive logic intact up to 80 lines. |
| **Parameter Dumping** ($>4$ arguments) | Slicing methods with shared local state | Keep logic unified or extract an immutable value object/struct. |
| **`rescue nil` Shielding** | Masking state bugs introduced by decomposition | Remove artificial boundaries; allow invariants to fail fast with descriptive messages. |
| **`rescue Exception`** | Catching "everything" defensively | Rescue only `StandardError`; permit signals and process exits to propagate cleanly. |
