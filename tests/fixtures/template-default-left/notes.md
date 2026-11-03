# `template-default-left`

A template placeholder that was never replaced. The templates ship their tripwires on purpose,
so this is the rule that stops a half-instantiated project passing for a finished one.

| | |
|---|---|
| `bad` | `OrchestratorQueueName` still `[UC-SPECIFIC — replace]` |
| `good` | a real queue name |

The rule also covers the `<PROJECT-NAME-TBD-ask-team>` project name, the stock
`ProcessABCQueue`, the stock `logF_BusinessProcessName` of `Framework`, and the two template
GUIDs. Only the marker form is fixtured; the others share the same rule id and code path.