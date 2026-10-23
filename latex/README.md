# LaTeX and mathematical exposition

Author-approved classification, October 23, 2026: precision and low-level
LaTeX mechanics are requirements; higher-level exposition rules are defaults.
This package does not itself change global agent settings.

Start with [the conventions review](CONVENTIONS-REVIEW.md), then use
[GUIDELINES.md](GUIDELINES.md) when writing. [RATIONALE.md](RATIONALE.md)
records the sources and explains the choices. [EXAMPLES.md](EXAMPLES.md)
shows how the guidance affects actual exposition. Use
[CHECKLIST.md](CHECKLIST.md) when completing a revision.

The standard covers mathematical and algorithm papers as well as LaTeX source
organization. It distinguishes requirements for precision and LaTeX mechanics
from writing defaults and project-specific build/layout settings. It imposes no
sentence-length quotas, theorem counts, compulsory pseudocode package, or
automatic readability score.

## Skill workflows

The standard defines stable requirements. The installed skills supply detailed
commands, configurations, API guidance, and production workflows. They are
external dependencies, not files in this repository. In the author's installation:

- `~/.codex/skills/latex-fix/SKILL.md` defines the LaTeX workflow; its
  `assets/example/` directory contains the starter paper, prefix, bibliography,
  and formatter configuration.
- `~/.codex/skills/draw-figures/SKILL.md` defines the mathematical figure workflow.

Use the skill locations provided by the current environment when they differ.

In particular, run the layout normalizer and `tex-fmt` on revised manuscript
sources. Mark definitions of reused key concepts with `\emphi{...}`; ordinary
`\emph{...}` is not visually prominent enough for this purpose.

The skill scripts are reused, not copied or replaced. Builds follow the target
paper's instructions. Compiling and checking conventions do not verify a proof.

For genuine venue or project conflicts, follow the narrow-exception procedure in
[GUIDELINES.md](GUIDELINES.md#9-resolve-genuine-convention-conflicts-narrowly).

Projects can adopt the standard using
[templates/AGENTS_SNIPPET.md](templates/AGENTS_SNIPPET.md). Do not install that
snippet into global or project instructions automatically.

The writing references are linked in RATIONALE.md. No third-party book text or
scanned handouts are redistributed in this package.
