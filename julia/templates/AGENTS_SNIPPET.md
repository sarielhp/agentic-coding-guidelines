## Julia Tooling and Authorization

Follow the Julia [GUIDELINES](~/prog/standards/julia/GUIDELINES.md) and
[RATIONALE](~/prog/standards/julia/RATIONALE.md). Code is formatted with
JuliaFormatter's default style (`.JuliaFormatter.toml`); formatting changes go in their
own commit.

Use the exact command forms when applicable:

| Command | Use |
|---|---|
| `rtk proxy julia-audit --strict` | Depth, complexity, size, idiom and trap audit |
| `rtk proxy julia-static-analysis [paths]` | Syntax, formatting; JET and imports for a project |
| `rtk proxy julia-static-analysis --aqua` | Aqua package checks (also run by the test suite) |
| `rtk proxy julia --project=. -e 'using Pkg; Pkg.test()'` | Run the test suite |

Projects that copied the lifecycle templates also have these (`tools/<name> --help`
says what each one does and runs nothing):

| Command | Use |
|---|---|
| `rtk proxy tools/build` | Check the declared scripts and precompile |
| `rtk proxy tools/gate` or `rtk proxy tools/check` | Fast gate; add `--full` for release verification |
| `rtk proxy tools/lint` / `tools/test` | Static feedback / the test suite |
| `rtk proxy tools/snapshot [message]` | Local checkpoint without gate/push |
| `rtk proxy tools/commit [--full] <message>` | Requested gated local commit |
| `rtk proxy tools/bump [major\|minor\|patch]` | Requested version bump and verified push |
| `rtk proxy tools/bump --resume` | Resume an inspected failed push without bumping again |
| `rtk proxy tools/release [--install] <message>` | Requested release: commit, bump, push; never registers |
| `rtk proxy tools/publish [release notes]` | Registration in General; see below |

**Publishing is rare and needs an explicit request.** A release pushes a new version
and is routine once asked for; it does not register the package. `tools/publish`
registers the released version in Julia's General registry, which is public and
cannot be withdrawn. Run it only when the user explicitly asks to publish or
register, typically after major or breaking changes, and never as part of a
release, a bump, or "finishing up". `tools/publish --dry-run` shows what would be
registered and changes nothing.

Run routine audits and tests for authorized work. Existing command approval allows
execution; it does not authorize commits, releases, registration, or changes outside
the task. Reuse authorization already given in the session. Keep sandboxing and manual
approval review enabled. Bootstrap the analysis packages separately, when authorized, with
`julia-install-tools`; the gates never install anything. Never enlarge an allow marker
(`# julia-audit: allow-<rule>`) to hide a new finding.

Before any refactor of numerical code, record the outputs on fixed inputs and require
bit-identical results afterwards; a result change is its own deliberate commit.
