# `not-a-project`

The path given is not a project folder. Worth a fixture because it is the rule that guards
every other rule: if this one stopped firing, pointing the checker at the wrong directory would
report PASS over nothing at all.

| | |
|---|---|
| `bad` | `fixture.json` removes `project.json` |
| `good` | the base `project.json` is present |