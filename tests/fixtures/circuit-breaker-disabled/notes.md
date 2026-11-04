# `circuit-breaker-disabled`

`MaxConsecutiveSystemExceptions = 0` switches the guard off, so a broken environment is
hammered for the whole length of the queue instead of the job stopping.

| | |
|---|---|
| `bad` | `0` |
| `good` | `3` — the template default |