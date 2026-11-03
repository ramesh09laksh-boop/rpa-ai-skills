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