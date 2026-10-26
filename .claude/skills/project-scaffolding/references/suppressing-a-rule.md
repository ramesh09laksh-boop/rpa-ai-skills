# Suppressing a `validate-project` rule

A rule that is genuinely not applicable **yet** goes in a `validate-project.ignore` file beside
`project.json`. One `rule: reason` per line; indented lines continue the reason:

```
assets-parity: The credential Orchestrator assets do not exist yet, so the TST Assets sheet
  carries only the rows that resolve today. InitAllSettings resolves every Assets row at
  startup, so shipping rows for assets nobody has created fails Initialization.
```

A suppressed finding is **still printed**, with its reason. It just stops failing the run.

That is the whole design. A rule you can switch off silently is a rule nobody trusts six months
later, because there is no way to tell "we considered this and it is fine" from "someone turned
it off to get a green build". Writing the reason down costs thirty seconds and is the only thing
that distinguishes the two.

The checker also enforces this on itself: a suppression with no reason raises
`suppression-without-reason`.

## `-SkipRule` is for experimenting, not committing

```powershell
pwsh -File validate-project.ps1 <project> -SkipRule relative-persisted-path
```

Same effect, no written reason, nothing recorded. Use it while you are working out whether a
rule applies. Do not put it in a script, a CI job or a commit — that is what the `.ignore` file
is for.

## What a suppression is not for

- **A warning you have decided to live with.** If it is permanent, it needs the written reason
  in the `.ignore` file, not a skip.
- **A `WARN` dismissed as "pre-existing".** `relative-persisted-path` in particular is a
  documented silent-failure trap: at runtime the working directory is the *extracted package*,
  so a relative config path writes into a folder discarded on the next publish. In the case that
  produced the rule, the lost file was the audit log providing idempotency, and losing it
  silently re-armed duplicate emails to external parties.
- **A leaf-workflow-contract warning on a new scaffold.** `system-workflow-no-config`,
  `system-workflow-no-outcome`, `secret-argument-string` and `logic-workflow-no-arguments` are
  warnings because the rules are new, not because the contract is optional.

  Calibration, measured 2026-10-26 after tuning: 19 on TKB-UC11, 28 on UC81, 23 on UC39.
  **Not zero anywhere** — the estate's projects predate the contract. An earlier version of this
  file claimed UC39 reported zero; that was a measurement error (`grep` treated the project's
  non-ASCII output as binary and suppressed the lines). On an **existing** project these are a
  backlog, and a blanket suppression with a written reason is legitimate. On a **new** scaffold
  they are not.
