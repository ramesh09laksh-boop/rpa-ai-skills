# `silent-failure`

`ShouldMarkJobAsFaulted = False` means a job that processed nothing, or that hit the
consecutive-exception limit, still reports green in Orchestrator. The estate's signature silent
failure, and the rule is named after the class.

| | |
|---|---|
| `bad` | `False` |
| `good` | `True` |