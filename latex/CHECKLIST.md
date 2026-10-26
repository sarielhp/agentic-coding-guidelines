# Completion checklist

Use for a paper revision; it is not a substitute for mathematical review. Record
each applicable item as done or incomplete. Mark an item not applicable only
when it is outside the change's scope, with a brief reason when not obvious.
Report unavailable tools or blocked checks as incomplete, not as passes.

- [ ] **Algorithm exposition:** affected procedures have clear inputs, outputs,
  steps, correctness arguments, and resource bounds at the intended level of
  detail. Referenced structures are available when used.
- [ ] **Required source formatting:** the `latex-fix` normalization and `tex-fmt`
  workflow ran with its prescribed configuration and exclusions. The diff was
  inspected for unintended mathematical or typographic changes.
- [ ] **References and conventions:** the convention checker ran; citations,
  typed references, label targets, and relevant diagnostics were checked.
- [ ] **Definition visibility — manual:** defining occurrences of reused key
  concepts, including inline definitions, use the `sariel.sty` version of
  `\emphi`, with its color, bold italics, and index hook. Their appearance is
  checked in the rendered PDF. Ordinary emphasis and later mentions
  have not been indiscriminately converted. Do not infer this result solely from
  formatter or search output.
- [ ] **Build and pages:** the paper builds using its recorded workflow; relevant
  alerts were resolved, and changed PDF pages were inspected at reading size.
- [ ] **Figures, when changed:** generators ran; matching nonempty PDF/Ipe files
  and editable sources are present; every figure page was inspected. Integrated
  labels, references, final size, and the combined caption/prose budget were
  checked. Any necessary budget exception has the required source comment.
- [ ] **Conflicts:** any real venue or project conflict has a narrow documented
  resolution. Unaffected requirements remain in force.
- [ ] **Completion report:** distinguish document production, mathematical review,
  and experiments. Identify outstanding checks without claiming a proof was
  verified by a successful build.

Exact commands, tool configuration, and production steps belong in the skills
and the project's build instructions. Do not maintain a competing workflow here.
