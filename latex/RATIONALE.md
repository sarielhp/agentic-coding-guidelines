# Rationale and sources

This is an original working standard assembled from the author's preferences,
the existing LaTeX workflow, and selected writing references. It is not a summary
of every recommendation in a writing book. The approved distinction between
requirements and defaults is documented in CONVENTIONS-REVIEW.md.

## Sources and reading scope

**Author's conventions, October 23, 2026.** The core preferences come from the
triangulation-paper discussion: explicit contracts when needed; an algorithm
description separate from its analysis; correctness usually before running time;
headings only for long, complicated procedures; informative section openings;
and concise treatment of standard constructions. The author subsequently asked
to review which conventions should be optional, and approved flexible writing
defaults while requiring the mechanics in `latex-fix`. In particular, source
reindentation and `\emphi{...}` for reused key concepts are requirements.
The author also endorsed using `draw-figures` for figure work.

**Knuth, Larrabee, and Roberts, Mathematical Writing.** Consulted the available
lecture text, with focused reading of sections 1, 8, 10--11, 14--16, 18--19,
25, 27, 31, 34, and 40--43. This was not a cover-to-cover reading of all exercises
and historical material. Printed section and page numbers, not PDF page numbers,
identify the passages below.

Useful takeaways:

- Section 1, pp. 1--6: explain notation at introduction, connect formulas with
  prose, and help the reader understand why the next concept appears.
- Section 10, pp. 20--22: algorithm presentation needs consistent conventions;
  a famous author's personal style need not be copied wholesale.
- Sections 18--19, pp. 37--40: diagrams and a repeated example can reveal
  structure that words alone obscure.
- Section 27, pp. 59--60: make the contribution easy to find, including for a
  reader skimming theorem statements; avoid excessive preliminaries.
- Section 31, pp. 69--71: examples test an exposition, and organization matters
  more than surface formatting.
- Sections 40--43, pp. 100--115: automated advice needs judgment; direct proofs
  can improve exposition; some earlier stylistic prescriptions are disputed or
  qualified later in the report.

[Author's page and errata](https://cs-faculty.stanford.edu/~knuth/klr.html).
[Consulted PDF mirror](https://yurichev.com/mirrors/Donald%20Knuth/mathwriting.pdf).
The 119-page PDF was rendered from TeX and omits some inserted handouts and
illustrations. In particular, the text discusses Lamport's proof handout, but
the handout itself is absent. No claim here relies on inspecting it.

**Jeff Erickson, Algorithms, Section 0.5.** The interface and algorithm should
be precise enough for a reader to use and implement them, with analysis supplied
separately. The discussion also distinguishes useful abstraction from irrelevant
programming-language detail. Consulted the section in the
[introductory chapter](https://jeffe.cs.illinois.edu/teaching/algorithms/book/00-intro.pdf).
The present standard follows the author's preferred analysis order, rather than
requiring the order of that textbook.

**Existing latex-fix skill.** Source organization, typed references, bibliography
tools, formatter/checker usage, and definition typography come from the
[local skill](README.md#skill-workflows), not from the writing
report. The separation of mathematical scope from mechanical validation is an
explicit design choice of this standard.

**Existing draw-figures skill.** The Julia/Ipe production workflow, matching
editable/vector artifacts, mathematical labels, visual inspection, and combined
caption/prose budget come from the
[figure skill](README.md#skill-workflows). Its mechanically
specified requirements apply when figures are made; deciding whether a picture
helps the argument remains an editorial judgment.

## Why the distinctions matter

A procedure can be precise without having a heading called "Input". Conversely,
four headings can conceal an unspecified data structure or a missing recursive
case. The requirement is that the reader can determine what the procedure
receives, does, and guarantees. The usual four-part presentation supports that
requirement; its visual form is flexible.

Repeated specifications are useful when readers consult a subroutine separately.
They become noise when a one-sentence operation simply uses the immediately
preceding objects. The standard therefore recommends repetition without making
it a quota.

A short description of a familiar hierarchy can be sufficient, while a single
sentence about a new geometric selection rule can be inadequate. Length is not
the criterion: the unexplained decision and its consequences are. Similarly,
an illustrative example can expose a missing case, but it cannot establish the
general claim.

Correctness first is a useful default because it tells the reader why the work
being counted solves the problem. A resource lemma can sometimes make the proof
easier to follow; nothing is gained by forcing it later. The algorithm itself
should remain locatable independently of either analysis.

The required LaTeX mechanics make source files predictable and references easier
to audit. Reindentation is cheap and repeatable, so a short edit is not a reason
to skip it. Consistent source formatting does not constrain the author's prose
structure. Build commands and page layouts remain project-specific.

Definition typography also serves an explicit reader need: ordinary italics do
not make a defining occurrence visible enough for this author. Therefore
`\emphi{...}` is required for reused key concepts, even when the definition
environment itself is optional. A bold-italic implementation is provided by the
skill's prefix. This decision should not be weakened to an ordinary style preference.

Stable requirements belong here; executable steps belong in the skills and paper
build instructions. This avoids conflicting copies of a command sequence when
a tool changes. The completion checklist checks outcomes and explicitly includes
a human reading of definitions, since formatting alone cannot determine their
semantic role or visual prominence.

A documented venue conflict should change only the affected requirement. This
keeps a bibliography constraint from becoming an excuse to abandon formatting,
reference checks, or definition visibility throughout the paper.

## Limits on automation and enforcement

The existing checker can detect certain source conventions; it cannot decide
whether a definition is understandable, a proof is complete, or the running-time
bound charges every operation. Those remain reading tasks. Do not manufacture
hard limits on sentence length, notation count, or proof length to make them
look machine-checkable.

Do not inherit the report's historical pronoun preferences, publishing logistics,
or disputed grammar rules as universal requirements. The standard deliberately
uses current, ordinary language and preserves author judgment. Exceptions to a
default normally need no explanation; document one when it could otherwise look
like an omission in the argument or an unperformed check.
