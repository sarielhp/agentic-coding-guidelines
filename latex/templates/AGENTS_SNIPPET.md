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
- Apply `latex-fix`: shared prefix, typed references, BibLaTeX/Biber, label and
  math layout, required normalization and `tex-fmt` reindentation, and the
  convention checker. Use `\emphi{...}` when defining reused key concepts;
  ordinary `\emph{...}` is not sufficiently visible for this purpose.
- Use `draw-figures` for mathematical figure work, including its Julia/Ipe/PDF
  artifacts, regeneration, label, caption-budget, and inspection requirements.
- Follow the paper's recorded build command. Distinguish mechanical checks,
  mathematical review, and experiments in completion reports.
- Use `CHECKLIST.md` before reporting completion, including the manual source
  and PDF check of definition visibility. Follow the narrow-conflict procedure
  in `GUIDELINES.md`; keep detailed tool commands in the skills and project notes.
```

Record the paper's actual main file, build command, auxiliary location, and
formatting choices separately. Do not import the triangulation project's
general-position assumptions, page layout, or numbered-version workflow into
unrelated papers by default.
