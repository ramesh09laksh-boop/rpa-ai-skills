# `unattended-contradiction`

`isAttended: false` with `requiresUserInteraction: true` — an unattended job that will block on
a dialog nobody is there to see. It does not fail; it hangs.

| | |
|---|---|
| `bad` | `isAttended: false`, `requiresUserInteraction: true` |
| `good` | both `false` |