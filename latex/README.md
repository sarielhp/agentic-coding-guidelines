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

## Standard tooling and workflows

The LaTeX standard is fully self-contained in this repository. All execution tools,
configuration templates, and starter assets are provided locally:

### Execution Tools (`tools/`)
The standard tools are located in [tools/](tools/) and symlinked to `~/bin/`:
- [tools/latex_fix_layout](tools/latex_fix_layout): Layout normalizer. Isolates math displays (`\[...\]`), multiline math (`\begin{math}...\end{math}`), and typed labels (`\lemlab{...}%`) on their own lines before formatting.
- [tools/latex_indent](tools/latex_indent): Formatter and indenter using `tex-fmt`. The 4-space, 72-column configuration is embedded directly into the script; copying `tex-fmt.toml` into project repositories is explicitly forbidden to prevent configuration drift.
- [tools/latex_check_conventions](tools/latex_check_conventions): Read-only static convention auditor. Verifies typed labels, BibLaTeX/Biber, label line layout, and figure structure.
- [tools/tex_source.rb](tools/tex_source.rb): Shared LaTeX parser that strips comments and protects verbatim/listing environments.

### Starter Templates (`templates/`)
Starter manuscript sources and templates are maintained in [templates/](templates/):
- [templates/example.tex](templates/example.tex): Minimal starter paper illustrating standard structure and environments.
- [templates/prefix.tex](templates/prefix.tex): Shared prefix providing theorem definitions, `\emphi`, and typed reference macros.
- [templates/references.bib](templates/references.bib): Sample BibLaTeX bibliography.
- [templates/tex-fmt.toml](templates/tex-fmt.toml): Reference copy of the standard `tex-fmt` configuration.
- [templates/AGENTS_SNIPPET.md](templates/AGENTS_SNIPPET.md): Instructions snippet for adopting projects.

### Mathematical Figure Workflow
For mathematical figures, follow Section 7 using the `draw-figures` workflow (generating matching vector PDF, editable Ipe, and reproducible Julia source).

In particular, run the layout normalizer (`tools/latex_fix_layout`), reindent revised manuscript
sources with `tools/latex_indent`, and run the convention checker (`tools/latex_check_conventions`).
For reindentation, projects must copy the `tools/latex_indent` script from this repository directly
and use it; copying `tex-fmt.toml` into project repositories is explicitly forbidden to prevent
configuration drift. The standard formatter configuration is embedded directly in `tools/latex_indent`
(and stored in `templates/tex-fmt.toml`).
Mark definitions of reused key concepts with `\emphi{...}`; ordinary
`\emph{...}` is not visually prominent enough for this purpose.

The standard tools (`latex_fix_layout`, `latex_indent`, and `latex_check_conventions`) in `tools/`
are reused directly. Builds follow the target paper's instructions. Compiling and checking conventions
do not verify a proof.

For genuine venue or project conflicts, follow the narrow-exception procedure in
[GUIDELINES.md](GUIDELINES.md#9-resolve-genuine-convention-conflicts-narrowly).

Projects can adopt the standard using
[templates/AGENTS_SNIPPET.md](templates/AGENTS_SNIPPET.md). Do not install that
snippet into global or project instructions automatically.

The writing references are linked in RATIONALE.md. No third-party book text or
scanned handouts are redistributed in this package.
