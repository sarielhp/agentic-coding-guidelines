# Completion checklist

Use for a paper revision; it is not a substitute for mathematical review. Record
each applicable item as done or incomplete. Mark an item not applicable only
when it is outside the change's scope, with a brief reason when not obvious.
Report unavailable tools or blocked checks as incomplete, not as passes.

- [ ] **Algorithm exposition:** affected procedures have clear inputs, outputs,
  steps, correctness arguments, and resource bounds at the intended level of
  detail. Referenced structures are available when used.
- [ ] **Required source formatting:** the normalization (`tools/latex_fix_layout`)
  and `tex-fmt` workflow ran using `tools/latex_indent` (copied directly from standards;
  copying `tex-fmt.toml` is explicitly forbidden) with its prescribed exclusions. The
  diff was inspected for unintended mathematical or typographic changes.
- [ ] **References and conventions:** the convention checker (`tools/latex_check_conventions`)
  ran; citations, typed references, label targets, and relevant diagnostics were checked.
- [ ] **Definition visibility:** defining occurrences of reused key concepts
  were read for meaning and checked for the `sariel.sty` version of `\emphi`,
  including its color, bold italics, and index hook. Compiled font/color data
  were checked where available, and representative occurrences in each affected
  style or layout, plus flagged or uncertain ones, were visually inspected.
  Ordinary emphasis and later mentions have not been indiscriminately converted.
  Neither source checks alone nor PDF metadata alone establish visual clarity.
- [ ] **Build and targeted PDF checks:** the paper builds using its recorded
  workflow; relevant diagnostics and available text/layout checks were assessed.
  Changed figures, flagged regions, and representative affected layouts were
  visually inspected at a readable size under Section 8 of `GUIDELINES.md`.
  Full-page images were used where page context mattered; a whole-paper image
  pass was not required merely because prose or pagination changed.
- [ ] **Figures, when changed:** generators ran; matching nonempty PDF/Ipe files
  and editable sources are present; every new or modified figure page was
  inspected. Integrated labels, references, final size, and the combined
  caption/prose budget were checked. Any necessary budget exception has the
  required source comment.
- [ ] **Conflicts:** any real venue or project conflict has a narrow documented
  resolution. Unaffected requirements remain in force.
- [ ] **Completion report:** distinguish document production, mathematical review,
  and experiments. Record automated checks, actual visual coverage, and outstanding
  concerns. Do not present sampled visual checks as a complete visual pass or
  claim a proof was verified by a successful build.

Exact commands, tool configurations, and production steps are provided by the
repository tools ([`tools/latex_fix_layout`](tools/latex_fix_layout), [`tools/latex_indent`](tools/latex_indent),
[`tools/latex_check_conventions`](tools/latex_check_conventions)) and the project's build instructions.
Do not maintain a competing workflow here.
