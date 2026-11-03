# `system-workflow-no-outcome`

An `<App>_System/` workflow that returns nothing makes a no-op indistinguishable from success to
its caller. One of the four leaf-CONTRACT rules.

| | |
|---|---|
| `bad` | `in_Config` + a business key in, nothing out |
| `good` | the same plus `out_Status` |