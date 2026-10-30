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

## Lifecycle templates

`templates/` holds the same lifecycle helpers as the Ruby and Rust standards, on the same
shared `tooling.rb` (kept byte-identical across the three), with Julia's specifics in
`language.rb` and `settings.rb`: `build`, `gate`/`check`, `lint`, `test`, `snapshot`,
`commit`, `bump`, `release`, `install`, and the Julia-only `publish`. Copy them into a
project's `tools/`, dropping the `.rb` suffix except on `tooling.rb`, `language.rb` and
`settings.rb`. Every script answers `-h`/`--help` and runs nothing.

| Step | What it does |
|---|---|
| `tools/gate` | `julia-audit --strict`, `julia-static-analysis --syntax --format`, `Pkg.test()`, precompile; `--full` adds JET and ExplicitImports |
| `tools/release <message>` | Commit, bump the version in `Project.toml`, run the full gate, push. Frequent; never registers |
| `tools/publish [notes]` | Register the pushed release in General: wait for `PUBLISH_WORKFLOW` on the commit, then comment `@JuliaRegistrator register`. Rare, and only on explicit request |

Releasing and registering are separate on purpose. A release only pushes a version; a
registration is public and permanent. `RELEASE_TAG` is `false` by default because
TagBot tags a registered package once its registration merges; set it to `true` for a
project that is never registered, and the bump then pushes a `vX.Y.Z` tag itself.
`GITHUB_REPO` (default: read from the upstream remote) and `PUBLISH_WORKFLOW` (default
`CI.yml`) configure `tools/publish`. A package's executable scripts can be listed in
`ARTIFACTS` to be checked by `tools/build` and copied by `tools/install`.

## Tests

`../test/julia_audit_test.rb` and `../test/julia_static_analysis_test.rb` are the acceptance tests; they need Julia ≥ 1.10 (the static-analysis tests also need a tools environment and skip themselves without one). See [../test/README.md](../test/README.md).
