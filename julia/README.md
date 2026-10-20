# Julia engineering standards and tooling

[GUIDELINES.md](GUIDELINES.md) defines the structural limits, method and file tiers, idioms, Julia-specific traps, testing rules, and the quality gates. [RATIONALE.md](RATIONALE.md) explains the rules and records the evidence behind them. The limits (nesting ≤ 4, cognitive complexity ≤ 15, 80/120-line tiers) are the same as for the other languages.

## Tools

| Tool | Purpose |
|---|---|
| `bin/julia-audit` | AST auditor: nesting depth, cognitive complexity, method length tiers, file size, argument count, idiom and trap rules. Measures with `Base.JuliaSyntax` through `bin/julia-ast-metrics.jl`; needs Julia ≥ 1.10 and no packages. |
| `bin/julia-static-analysis` | `--syntax`, `--format` (JuliaFormatter), `--jet`, `--imports` (ExplicitImports), `--aqua`. |
| `bin/julia-install-tools` | Audits or creates the dedicated tools environment holding JuliaFormatter, JET, ExplicitImports, and Aqua. `--check-only` changes nothing. |
| `bin/julia-checks.jl` | Julia-side runner used by `julia-static-analysis`. |
| `bin/analysis_support.rb` | Shared support (keep it beside the wrappers). |

```bash
julia-audit --strict                      # whole project (src/, ext/, bin/, tools/, scripts/, root *.jl)
julia-audit --strict --include-tests      # also test files
julia-audit -v src/Geometry.jl            # show the most complex functions of one file
julia-static-analysis                     # syntax + formatting (+ JET and imports inside a project)
julia-static-analysis --jet --imports src # explicit checks for a package
```

Options of `julia-audit`: `--max-depth`, `--max-complexity`, `--max-logic-lines`, `--max-declarative-lines`, `--max-args`, `--soft-file-lines`, `--max-file-lines`, `--include-tests`, `--strict`, `-q`, `-v`. Suppress one finding on its line with `# julia-audit: allow-<rule>` and a reason; exempt a whole long data file with `# julia-audit: allow-long-file`.

Exit status: 0 passed; 1 violations (or warnings with `--strict`); 2 tool or usage error. Parse errors are violations.

## Tools environment

The analysis packages are installed into one Julia environment, `~/.julia/environments/standards-julia` (override with `JULIA_STANDARDS_ENV`), never into a project. The gates do not install anything. Audit or bootstrap separately:

```bash
julia-install-tools --check-only   # report what is missing
julia-install-tools                # install into the tools environment (requires explicit authorization)
```

`julia-static-analysis` runs JET, ExplicitImports, and Aqua inside the project's own environment with the tools environment stacked behind it (`JULIA_LOAD_PATH`), so the project loads with its own dependencies. The project must be instantiated.

## Adopting the standard in a project

1. Copy [templates/dot_JuliaFormatter.toml](templates/dot_JuliaFormatter.toml) to `.JuliaFormatter.toml`, format the code in one formatting-only commit, and verify behavior is unchanged.
2. Add [templates/AGENTS_SNIPPET.md](templates/AGENTS_SNIPPET.md) to the project's agent instructions.
3. Run `julia-audit --strict` and `julia-static-analysis`; fix findings or record justified `allow` markers.
4. Put `Aqua.test_all` in the test suite.

Lifecycle helpers (`tools/build`, `gate`, `commit`, `bump`, `release`, …) are not provided for Julia yet. Julia projects that register in General use the registry's own release flow.

## Tests

`../test/julia_audit_test.rb` and `../test/julia_static_analysis_test.rb` are the acceptance tests; they need Julia ≥ 1.10 (the static-analysis tests also need a tools environment and skip themselves without one). See [../test/README.md](../test/README.md).
