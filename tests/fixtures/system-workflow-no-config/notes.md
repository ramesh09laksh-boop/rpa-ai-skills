# `system-workflow-no-config`

An `<App>_System/` workflow with no `in_Config` cannot see the window titles, timeouts and
paths it needs — which means they are hardcoded. One of the four leaf-CONTRACT rules.

| | |
|---|---|
| `bad` | declares arguments, but not `in_Config` |
| `good` | declares `in_Config` |

The rule only applies to a workflow that declares SOME arguments, and skips `_`-prefixed
developer scratchpads.