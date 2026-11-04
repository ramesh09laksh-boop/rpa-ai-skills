# `assets-empty`

Fires when a project references a banking library but its `Assets` sheet has no rows — the
credentials have to come from somewhere, and every alternative is worse.

| | |
|---|---|
| `bad` | `Swisscom.FinnovaLibrary` in `dependencies`, Assets sheet header-only |
| `good` | the same dependency, with one Assets row |

The dependency is what arms the rule, so `good` must keep it. A fixture that dropped the
dependency would pass by making the rule inapplicable rather than satisfied.