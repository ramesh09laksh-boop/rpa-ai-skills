# `suppression-without-reason`

`validate-project.ignore` suppresses a rule with nothing after the colon. A suppression that
can be switched on silently is a suppression nobody can audit, so the reason is mandatory and
its absence is itself a finding.

| | |
|---|---|
| `bad` | `unresolved-mock:` with an empty reason |
| `good` | `unresolved-mock: <a written reason>` |

A suppressed finding is still PRINTED, with its reason — it just stops counting towards the
exit code. The runner matches `muted` lines as well as `error`/`warning` for that reason.