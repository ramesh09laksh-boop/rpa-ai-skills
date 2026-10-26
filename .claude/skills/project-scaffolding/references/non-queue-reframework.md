# REFramework without an Orchestrator queue

Both Performer templates assume an Orchestrator queue in two places, and **neither is flagged in
their deltas**. Fetch a Performer for a process that has no queue and it will run green having
processed nothing — the same silent failure the repo warns about for a mismatched queue name.

## Three things must change together

| What | Stock | With no queue |
|---|---|---|
| `Framework/GetTransactionData.xaml` | Get Transaction Item against `in_Config("OrchestratorQueueName")` | Read the source **once** on the first pass (`in_TransactionNumber = 1`), hold it in a `DataTable`/collection, then hand out one item per call and `Nothing` when exhausted |
| `Constants!MaxRetryNumber` | `0` — "must be 0 when working with Orchestrator queues" | **Non-zero.** With no queue there is no queue definition to carry the retry count, so `0` means a transient failure is never retried at all |
| `Settings!OrchestratorQueueName` | `[UC-SPECIFIC — replace]` | `(not used - no queue)`. An explicit value shows the key is deliberately unused; an empty cell is indistinguishable from one nobody filled in |

Changing one or two of the three is worse than changing none, because the result looks wired.

## Knock-on changes

`in_TransactionItem` stops being a `QueueItem` and becomes whatever your source yields — a
`DataRow`, a mail, a file path. Every workflow that consumes it changes type with it.

`SetTransactionStatus.xaml` must lose its queue calls **while keeping** the retry counter, the
circuit-breaker counter and the failure screenshot. Those are not queue features; dropping them
along with the queue calls is the easy mistake, and it removes the circuit breaker the
`validate-project` rules exist to protect.

## The guard that makes this safe

> **If a configured source yields 0 transactions, log an `Error` and fail visibly.**

Without a queue there is no Orchestrator view of "how much work was there", so a source that
silently reads nothing is invisible. See the `standards` skill, `references/wiring-the-framework.md`,
and the `standards` skill, `references/silent-failure-traps.md` →
*"A Performer that ends instantly with 0 transactions"*.

## What the checker will and will not catch

`validate-project` **will not** flag a non-zero `MaxRetryNumber` — that is the correct value
here. It **will** flag an `OrchestratorQueueName` left at the stock placeholder, which is why
the explicit `(not used - no queue)` value matters.
