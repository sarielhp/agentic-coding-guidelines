# Optional project instructions

Use this snippet when adopting the standard in a project. Do not copy it into
global settings automatically.

```markdown
## Mathematical writing and LaTeX

- Follow the precision requirements, required LaTeX mechanics, and writing defaults in
  `/home/sariel/prog/standards/latex/GUIDELINES.md`. Read `RATIONALE.md` when
  the reason for a convention matters. Defaults allow ordinary editorial
  judgment; they do not require a permission request for each exception.
- Prefer input/output, algorithm, correctness, then running time. Use headings
  only for long, complicated descriptions. Keep standard constructions concise.
- Apply the LaTeX standard tooling: normalize math delimiters and labels with
  `latex_fix_layout`, reindent with `latex_indent` (copy
  `/home/sariel/prog/standards/latex/tools/latex_indent` to `tools/latex_indent`
  and use it directly; copying `tex-fmt.toml` into project repositories is
  explicitly forbidden), and audit compliance with `latex_check_conventions`.
  Use `\emphi{...}` when defining reused key concepts; ordinary `\emph{...}` is
  not sufficiently visible for this purpose.
- Use `draw-figures` for mathematical figure work, including its Julia/Ipe/PDF
  artifacts, regeneration, label, caption-budget, and inspection requirements.
- Follow the paper's recorded build command. Distinguish mechanical checks,
  mathematical review, and experiments in completion reports.
- Use `CHECKLIST.md` before reporting completion, including semantic review of
  definitions and targeted checks of their compiled appearance. Read prose and
  mathematics as text; use diagnostics and structured PDF data to select visual
  checks of changed figures, flagged regions, and representative layouts.
  Do not routinely render or inspect every page image after prose edits.
  Record actual coverage. Follow the narrow-conflict procedure
  in `GUIDELINES.md`; keep detailed tool commands in project notes and standard tools.
```

Record the paper's actual main file, build command, auxiliary location, and
formatting choices separately. Do not import the triangulation project's
general-position assumptions, page layout, or numbered-version workflow into
unrelated papers by default.
