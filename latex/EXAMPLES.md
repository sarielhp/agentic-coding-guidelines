# Examples of applying the standard

These examples are original illustrations of the standard. They do
not prescribe a single voice or force headings onto short algorithms.

## A short algorithm with all four parts and no explicit headings

Given a nonempty sorted array `A[0..n-1]` and a key `x`, return the smallest
index `i` for which `A[i] >= x`, or `n` if there is no such index. Array access
and key comparisons take constant time.

Set `lo = 0` and `hi = n`. While `lo < hi`, let
`mid = floor((lo + hi)/2)`. If `A[mid] < x`, set `lo = mid + 1`; otherwise
set `hi = mid`. Return `lo`.

At every iteration all indices below `lo` contain keys less than `x`, and
all valid indices at least `hi` contain keys at least `x`. The update preserves
these statements because the array is sorted. The interval shrinks strictly.
At termination `lo = hi`, so the returned index has the required meaning,
including the case where it equals `n`.

Each iteration reduces the interval length by at least half and performs
constant work. The algorithm uses `O(log(n+1))` time and `O(1)` extra space.

The paragraphs supply a contract, a procedure, correctness, and cost. Giving
each paragraph its own heading would add little here.

## A familiar construction that should remain brief

> Recursively split each range at the median integer in its interior, stopping
> when its interior contains no integers.

This is enough when the range, indexing convention, and freedom to choose either
middle integer are already clear. Prove the cover-size property where it is
needed; do not expand the construction into an implementation tutorial. State a
specific tie convention only if it affects a later claim or reproducibility.

## A useful section opening

Weak: "This section describes the query structure."

More informative: "The sketch records only selected walls, so a query cannot
scan every original edge. We group its faces so that a query needs to inspect
one separator and at most one remaining group."

This explains the obstacle and what the section supplies, without narrating all
of its subsections in advance.

## State the available data

Weak: "Query the structure recursively."

More precise: "Query the two completed child structures and return the earlier
of their reported contacts. The parent's structure is still being built."

The second description makes the dependency explicit. Its correctness and cost
still belong in the subsequent analyses.

## A central definition using the required source conventions

```tex
\begin{definition}[Exit]
    \deflab{exit}%
    %
    An \emphi{exit} of a face is a retained vertical wall on its boundary.
\end{definition}
```

This illustrates source layout, not a universal definition of "exit". A paper
must specify the incidence conventions relevant to its geometry. By contrast,
"Let `m` be the number of edges in the current chain" normally needs no separate
definition environment.

If the exit definition is instead written inline, its defining occurrence must
still use `\emphi{exit}`. Define `\emphi` prominently in the prefix, for example
as `\textbf{\emph{#1}}`; plain `\emph{exit}` is not an acceptable substitute.
