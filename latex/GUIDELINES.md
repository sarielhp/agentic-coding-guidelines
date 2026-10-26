# Guidelines for mathematical papers and LaTeX

Classification approved by the author, October 23, 2026. See
[CONVENTIONS-REVIEW.md](CONVENTIONS-REVIEW.md) for the decisions. Precision and
low-level LaTeX mechanics are requirements; higher-level exposition rules are
defaults. Explicit user and project instructions take precedence.

## 1. Precision and honest scope

- Make each claimed result, its assumptions, and the meaning of its parameters
  identifiable. Define mathematical objects before using them substantively.
- Preserve distinctions that matter to the argument: geometry versus stored
  representation, preprocessing versus queries, existence versus construction,
  and an example versus a proof.
- Give enough information to justify the claimed result and resource bounds.
  Identify external theorems and the hypotheses needed to apply them.
- Report proof review, experiments, and document-production checks separately.
  A successful build or finite experiment does not certify a general theorem.
- Formatting and editorial changes must preserve mathematical meaning. If a
  purported clarification changes an assumption or guarantee, identify it as a
  mathematical change and check the affected uses.

## 2. Describe algorithms at a useful abstraction level

Prefer the following progression. These are parts of the exposition, not four
mandatory headings. Use headings only for long, complicated descriptions.

1. **Input and output.** State the objects received and the result returned.
   Include representations, preprocessing, supported operations, and failure
   behavior when they affect use or cost. Repeat earlier information when that
   saves the reader a search. Omit an explicit statement only when the immediate
   context makes it entirely clear.
2. **Algorithm.** Describe what happens without interleaving the cost analysis
   or proof. Specify the decisions and state changes needed to determine the
   procedure. For recursion, make the smaller instances and stopping condition
   clear. For a loop, describe an arbitrary iteration, not only an example run.
3. **Correctness.** Explain why the procedure terminates and meets its contract.
   Use the invariant, induction, or structural fact appropriate to the algorithm.
4. **Running time.** Define the size measure and account for relevant operations,
   preprocessing, recursive calls, and storage. Distinguish worst-case,
   amortized, and expected bounds when applicable.

Correctness and running time may appear in the opposite order, or be combined
for a simple procedure. Brief comments explaining a step can accompany the
description; the reader should not have to extract executable steps from a proof.

Use structured prose, lists, or pseudocode according to the procedure. Familiar
operations such as sorting, tree traversal, and balanced recursive partitioning
usually need only a short description. State any nonstandard convention that
affects the proof. Self-contained exposition does not require reimplementing
every standard primitive.

For hierarchical data structures, say what is already constructed at each call.
In particular, distinguish building a parent using completed children from
querying a completed parent. Avoid informal references to an oracle whose
construction depends on the operation currently being explained.

## 3. Organize for a reader who has not followed the research

- Give the problem, main result, and algorithm's broad structure early. For a
  long construction, provide a compact overview with references to its stages.
- Open substantive sections with their purpose and role. Make the explanation
  informative, such as naming the obstacle being resolved or the structure being
  constructed. Do not add a ceremonial preview to every short subsection.
- State the final argument directly. Keep superseded variants and research
  chronology in development notes unless needed to explain a current choice.
- Put the geometric or combinatorial mechanism before lengthy bookkeeping
  when possible. Keep dependencies explicit if proofs are deferred.
- Use an example when it exposes a difficult distinction. Reuse it when helpful,
  and ensure it exercises the feature being explained. Its role is explanatory;
  it does not replace a general argument.

## 4. Definitions, notation, and proofs

- Prefer definition environments for central concepts used repeatedly. Define
  short-lived notation inline. Put a brief interpretation near a formal
  definition if the interpretation makes it easier to use.
- **Required definition typography:** mark a key term being defined and used
  later with `\emphi{...}`, whether the definition is inline or in an environment.
  Ordinary `\emph{...}` and black bold italics do not implement the author's
  convention. Use the colored, indexing definition from
  `/home/sariel/papers/styles/sariel.sty`, reproduced below. Load that style or
  copy the three definitions into `prefix.tex` with `xcolor`; do not substitute
  the separate `\emphw` macro. Preserve the `\index` hook; producing a printed
  index is a separate manuscript choice. Keep ordinary emphasis
  and proof headings as `\emph`; do not mark every later use of a defined term.

  ```tex
  \usepackage{xcolor}
  \definecolor{blue25emph}{rgb}{0, 0, 11}
  \newcommand{\emphic}[2]{\textcolor{blue25emph}{\textbf{\emph{#1}}}\index{#2}}
  \newcommand{\emphi}[1]{\emphic{#1}{#1}}
  ```

  These are the literal color and macro definitions in `sariel.sty`. When
  synchronizing them, consult that file rather than choosing a substitute color.
- Use consistent names for distinct objects. Explain when multiple records or
  occurrences can represent the same geometric point. Avoid unnecessary indices
  and new terminology that do not support a later argument.
- Make principal theorem statements understandable without reconstructing
  unstated hypotheses from distant paragraphs. Previously defined terminology
  can be referenced rather than expanded at every use.
- Explain the decisive step in a difficult proof. Do not replace it by a claim
  that the conclusion is clear. Give long proofs a short route through their
  main steps; let short proofs remain short.
- Prefer the most direct readable argument. Do not mandate a proof style or
  introduce cases merely to fit a template.
- Use words to connect formulas and identify what an inequality or recurrence
  is counting. Long calculations should have an intelligible prose argument.

## 5. Prose and illustrations

Use concrete verbs, clear antecedents, and consistent terminology. Read important
passages for flow. Avoid unexplained jargon, long noun clusters, and references
such as "the above argument" when several arguments could be meant. Do not
enforce a sentence-length quota or automatically replace grammatical phrases.

Choose a figure to answer a specific question: what is adjacent, what changes,
which side is selected, or why a case differs. Labels and orientations should
match the text. Captions should say what the reader should notice. Keep labels
readable at the actual printed size; inspect the rendered page. Retain editable
sources, and do not rely on color alone to distinguish essential objects.

## 6. Required LaTeX mechanics

Apply the low-level conventions and workflow of
`latex-fix` (see [skill locations](README.md#skill-workflows)). These are requirements,
not discretionary exposition advice. Preserve metadata, citation targets, and
label identities. Follow explicit project build and page-layout instructions.

- Put imports, macros, theorem definitions, and reference helpers in `prefix.tex`.
  Keep the main file focused on the class, prefix input, bibliography resources,
  metadata, and body. Split long manuscripts by meaningful sections.
- Use BibLaTeX with Biber, `\addbibresource`, and `\printbibliography`.
  Do not mix in BibTeX commands. Check bibliographic facts against
  sources rather than trusting inherited entries.
- Use typed labels and references, such as `\lemlab`/`\lemref`,
  `\seclab`/`\secref`, and `\eqlab`/`\Eqref`. Define raw primitives only in
  the helpers. Use a deferred figure-label helper so the underlying label is
  assigned after the caption sets its number.
- Put a typed label on its own line. In a labeled environment, put it first,
  followed by a line containing only `%`, with the label line ending in `%`.
- Use `\emphi{...}` for a term being defined and reused, as required in Section 4;
  use ordinary emphasis for ordinary emphasis. If naming a work with three or
  more authors in prose, use `FirstAuthor \etal \cite{key}`.
- Use `\[ ... \]` for unnumbered displays and an appropriate numbered
  environment for numbered equations. Put math delimiters on separate source
  lines as specified by the skill. `\begin{math} ... \end{math}` is inline
  math, even when its source spans lines; never use a formatting pass to change
  an inline formula into a display or vice versa unintentionally. Preserve short
  inline `$...$`; replace `$$...$$` with display delimiters.
- Put figure assets under `figs/`, retain editable sources, and include separate
  PDFs for vector figures. Preserve existing editable TikZ sources. For
  mathematical figure work under `draw-figures`, follow Section 7.
- **Normalization and `tex-fmt` reindentation are required even for short edits.**
  Review the source diff and preserve mathematical meaning. Apply the skill's
  current workflow, configuration, and file exclusions; command sequences belong
  in the skill, not in a second copy here.
- Run the convention checks and the project's build. Fix broken citations and
  references, inspect significant layout warnings, and inspect changed PDF pages.
  If a tool is unavailable, report the unfinished check; hand formatting does
  not count as running it. Follow the completion checklist below.

Routine formatting does not authorize rewriting mathematical claims or a broad
grammar pass. Follow the skill's checks, including its test corpus if its scripts
are changed. Preserve meaning when repairing long displayed equations.

## 7. Mathematical figure workflow

Use `draw-figures` when creating or revising mathematical figures. Its full
instructions govern the work, including its stated preferences and exceptions.
Keep API calls, regeneration commands, and detailed production steps in the
skill and each figure's generator. The stable requirements are:

- Use Julia with QuickEnv, BasicCompGeometry's Ipe backend, and mathematical
  LaTeX labels. Follow the skill's reference material and verify APIs before use.
- Deliver matching vector PDF and editable Ipe files from the same backend,
  together with the reproducible Julia source. Follow the existing layout or use
  `figs/<name>.pdf`, `figs/<name>.ipe`, and `julia/<name>.jl`. Keep regeneration
  reproducible and independent of the caller's directory. Preserve manual
  Ipe edits. A PDF alone, or a raster image embedded in Ipe, is incomplete.
- Use actual mathematical labels and a self-contained figure macro preamble.
  Follow the skill's palette, contrast, arrowhead-clearance, and label conventions;
  inspect geometry and typography at the final inclusion size.
- Keep captions, subcaptions, and all figure-specific explanatory prose within
  six combined typeset lines, aiming below four. Count rendered lines, not source
  newlines. Longer necessary explanations require the nearby source comment
  specified by the skill; this is a documented exception, not an automatic
  permission request. Do not evade the budget by moving text into the artwork.
- Verify both nonempty artifacts, editable geometry, labels, and every rendered
  figure page. When integrating, check the manuscript's references, final figure
  size, and combined prose budget. Report unverified results accurately and keep
  scratch files outside the figure directory.

The choice to include a figure remains a writing judgment. These instructions
apply to figure work; they do not authorize adding figures during a discussion
or a request for suggestions only.

## 8. Final reading pass

Check that each algorithm's contract, procedure, correctness, and resource bound
can be found without assembling fragments from several proofs. Check symbol
definitions and the availability of every invoked structure. Follow overview
references to ensure they lead to the promised details. Inspect examples against
the stated assumptions. Finally review the source diff and compiled pages.

**Manually audit definition visibility.** Read the defining occurrences of key
concepts, including inline definitions, and check that they use `\emphi` in the
source and render with the specified color and bold italics in the PDF.
A formatter cannot reliably decide
which concepts are central, and a command search cannot establish that their
definitions are complete or legible. Do not claim this check from automation alone.

Use [CHECKLIST.md](CHECKLIST.md) to record completion. Unavailable checks remain
incomplete; checks outside the change's scope can be marked not applicable.

Treat automated diagnostics as specific observations, not verdicts on writing
quality or mathematical truth. Record material exceptions or incomplete checks
without turning ordinary editorial decisions into approval requests.

## 9. Resolve genuine convention conflicts narrowly

First distinguish a real constraint from an existing habit. A required venue
class or bibliography system can conflict with this standard; an old manuscript
using a different style is not by itself an exception to an authorized conversion.

Look for a compatible implementation that satisfies both requirements. If the
venue mandates BibTeX, for example, its bibliography workflow may need a specific
exception while typed references, reindentation, and prominent definitions remain
in force. Record the actual constraint, the affected convention, and the chosen
adaptation in the project's instructions or build notes. Keep the exception as
narrow as possible and identify any checks it makes inapplicable.

Do not silently weaken a reader-facing requirement such as definition visibility
to accommodate a template. Follow explicit user decisions already given; ask for
a choice only when a material conflict remains unresolved. Routine editorial
choices under the writing defaults do not require approval.
