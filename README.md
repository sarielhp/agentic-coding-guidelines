# Engineering Standards & AI Agent Guidelines

A centralized knowledge base and tooling repository defining architectural principles, cognitive limits, and automated quality enforcement across programming languages.

## Supported Languages

- [Go Standards & Tooling](go/README.md)
  - [Guidelines](go/GUIDELINES.md) — Operational rules, cognitive limits, and Google Go idioms
  - [Rationale](go/RATIONALE.md) — Cognitive load foundations, empirical reasoning, and anti-patterns
  - [CLI Tooling](go/bin/) — `go-audit`, `go-static-analysis`, `go-install-tools`
  - [Templates](go/templates/) — Pre-commit quality gates, Makefile snippets, and gated commits

## Global CLI Tools

Tools in `go/bin/` are symlinked to `~/bin/`:
- `go-audit`: Cognitive complexity and line auditor
- `go-static-analysis`: Multi-linter static analysis orchestrator
- `go-install-tools`: External linter installer
