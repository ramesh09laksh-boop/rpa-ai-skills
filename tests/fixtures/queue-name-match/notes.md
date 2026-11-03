# `queue-name-match`

The only cross-project rule, so the only fixture with two projects. A Dispatcher and its
Performer share one queue, and a mismatch throws nothing: the Dispatcher enqueues, the Performer
polls an empty queue, and BOTH jobs finish green with no work done.

| | |
|---|---|
| `bad` | `UC99_Fixture_Queue` vs `UC99_Fixtrue_Queue` — one transposition, exactly how it happens |
| `good` | byte-identical in both |