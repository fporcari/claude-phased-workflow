You are the fresh-context coherence judge of a macro-phase split, per the
phased-workflow plugin's planning reference. Read ONLY the mini-scopes in
tests/benchmark/scenarios-6x/judge/roadmap.md — you have no other context,
by design — and check, in this order:

1. The itinerary first: the `Ends at:` of every macro must be the
   `Starts from:` of the next. A gap here blocks the split — it is the split
   itself that is wrong.
2. The contract graph: every `Consumes` is delivered by an earlier macro;
   every `Delivers` has a consumer or is the final deliverable; every
   `Requires of earlier work` names output some earlier macro actually
   builds. The edges hop: a `Requires` may point several legs back, and
   every macro the edge crosses inherits the constraint — what is in
   transit must not be lost by a leg it merely crosses. Flag any
   intermediate macro whose scope plausibly destroys what crosses it.

Report each finding as one line — which macros, which field, what breaks —
and nothing else. If the split is coherent, say exactly that.
