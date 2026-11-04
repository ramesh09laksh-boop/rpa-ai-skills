# `leaf-name-prefix`

`naming-conventions.md`: `<Application>-<Subject>_<Verb>.xaml`, and *"the application prefix
matches the folder"*. So the prefix is derivable from the path — `Web_Nav_System/` →
`Web_Nav-`, `Finnova_System/` → `Finnova-` — which is exactly why nothing checked it, and why a
capture-and-develop loop can fill `Web_Nav_System/` with `Login.xaml` and `Extract_Table.xaml`.
Nothing downstream cares: they compile, analyze, pack and run.

The cost lands on the reader. A file name is the only index into a 60-workflow project, and a
leaf that does not say which application it drives sends the next developer to the wrong folder
— or to writing a second copy of a workflow that already exists.

| | |
|---|---|
| `bad` | `Web_Nav_System/Login.xaml` — no application prefix |
| `good` | `Web_Nav_System/Web_Nav-Login.xaml` |

Both separators pass (`Finnova-` and `Finnova_` are both live in the estate) and the comparison
is case-insensitive, because `SIX_ID_System/` holds `SIX_iD-Anlagefonds_…` and that drift is not
what this rule is about. A leading `_` is stripped before comparing rather than excused, and a
declared mock (`Mock*/`, `Mock-*`, `Mock_*`) is carved out for the same reason as in
`leaf-body-stub`: telling someone a mock is a mock is how a rule gets blanket-suppressed.
