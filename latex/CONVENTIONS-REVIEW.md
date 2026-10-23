# Review of required and optional conventions

Decision record, October 23, 2026. The author approved flexible higher-level
writing guidance and required the low-level conventions of `latex-fix`, especially
reindentation and prominent definition typography. Use `draw-figures` for
mathematical figure work. Explicit user and project instructions still apply.

**Requirement** means that the information or property must be present.
**Default** means to normally follow the recommendation, using judgment without
requesting permission for routine exceptions. **Project choice** means to select
a convention for the paper and apply it consistently. An option is not a reason
to change a working manuscript gratuitously.

| Convention discussed with the author | Treatment | Reason or exception |
|---|---|---|
| Exact algorithm input and output | Requirement for clarity; explicit restatement is a default | The reader must know the contract. A short procedure can inherit an unambiguous immediate context. |
| Repeat previously stated input/output | Default when it helps local reading | Repetition should prevent searching backward, not repeat obvious information mechanically. |
| Self-contained algorithm description | Requirement at the chosen abstraction level | Named subroutines and standard primitives can be referenced; their relevant contracts must be available. |
| Separate algorithm from analysis | Strong default | Do not bury operations in a proof. Brief explanatory comments or an invariant can remain beside a step when useful. |
| Correctness before running time | Default | Reverse the order if that makes dependencies clearer; combine simple analyses. |
| Four explicit headings for every algorithm | Optional; normally omit | Use headings only for a long, complicated description. |
| A few introductory sentences in each section | Default for substantive sections | A very short subsection may already explain its purpose in its first sentence. Avoid empty previews. |
| Compact algorithm overview in Section 1 | Early overview is a default; exact placement is a project choice | The triangulation paper specifically requires Section 1. Other papers may need brief setup first. |
| Key concepts in definition environments | Default for central, reused concepts | Define local notation inline. Do not create a separate environment for every variable. |
| A running example and figures | Recommended when they reduce abstraction | They are not mandatory for a short or already transparent argument. |
| Explain familiar constructions briefly | Default | Expand only the nonstandard detail needed for correctness or cost. |
| Shared prefix, typed references, BibLaTeX/Biber, separate figure files | Requirement under this standard | Follow `latex-fix`; these mechanics are not optional writing preferences. Preserve explicit project instructions and mathematical content. |
| Layout normalization and reindentation with `tex-fmt` | Requirement | Run the tools on revised manuscript sources with the skill's exclusions, then review the diff. A short edit is not a reason to skip formatting. |
| `\emphi{...}` when defining reused key concepts | Requirement of special importance | The author needs more visible definition typography than ordinary `\emph{...}`. Use it for defining occurrences, including inline definitions. |
| Label placement, reference helpers, and math-delimiter layout | Requirement | Apply the low-level `latex-fix` conventions consistently and run its checker. |
| Figure production and integration | Apply `draw-figures` when creating or revising mathematical figures | Follow its artifact, reproducibility, label, caption-budget, and inspection requirements. The decision to add a figure remains contextual. |
| `\usepackage[in]{fullpage}` | Project choice | Required in the current triangulation drafts; do not override a venue's mandated layout. |
| `latexmk -norc`, build wrapper, and auxiliary location | Project choice | Follow the paper's recorded build command. This repository's temporary-file rules still apply. |
| General position | Mathematical scope, not a universal writing convention | State exactly what is assumed; do not introduce assumptions solely to make prose shorter. |

Precision and faithful claims remain requirements. Ordering, repetition,
headings, and introductory prose remain defaults. Low-level LaTeX requirements
are independent of those defaults: choosing an inline definition rather than a
definition environment does not remove the requirement to use `\emphi` for its
reused key term. Build command and page layout remain project-specific.
