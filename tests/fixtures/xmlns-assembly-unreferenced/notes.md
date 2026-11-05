# `xmlns-assembly-unreferenced`

A workflow USES an xmlns prefix whose assembly is not listed in
`TextExpression.ReferencesForImplementation`. `uip rpa validate` passes clean and the UiRobot
pack then fails with *"Some references are not imported in current workflow"*, naming no file —
which is why this is an L2b failure and not an L2 one.

| | |
|---|---|
| `bad` | uses `acme:` with no `<AssemblyReference>Acme.Widgets</AssemblyReference>` |
| `good` | the same, with the assembly referenced |

The rule deliberately ignores a prefix that is DECLARED but never used — that is generator
boilerplate and projects full of it pack fine.

## The confirmed cause is a generator, not a typo

The **Object Repository linker** injects `sd:` / `sd1:` (`System.Drawing.Common` /
`System.Drawing.Primitives`) into every card-bearing workflow it links — they appear in the
Application Card's `OCREngine` delegate signature — and adds neither to
`ReferencesForImplementation`.

**Observed 2026-11-04: 14 findings over 7 linked workflows, with `uip rpa build` and
`uip rpa pack` both reporting Success.** So this rule is not only cheaper than `pack`; on that
project it was the **only** check that fired. Which is also why the `web` skill's capture loop ends
with a `validate-project` re-run *after* linking. Full note: the `standards` skill,
`references/silent-failure-traps.md`.

The fixtures use a synthetic `acme:` prefix rather than `sd:`, because the rule is about the
general shape and a fixture naming the real assemblies would read as being only about linking.