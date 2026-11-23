# What an SDD has to contain

The stage 1 gate is *"every transaction type and its work-item columns defined; Open Questions
listed"*. That is the **gate**, not the document. This file is the document — the sections an
SDD in this estate is expected to carry, so stage 1 produces a design somebody can build stage
2 and stage 3 from rather than a readable summary of the PDD.

It used to live in a prompt that got pasted by hand, which meant it was only as reliable as
whoever remembered to paste it. One section — the test strategy — existed nowhere else in these
skills at all.

## The sections

| Section | What it has to settle | Why it is here |
|---|---|---|
| **Business context** | What the process is for, who owns it, what volume it runs at | Decides whether a Dispatcher/Performer split is worth the second project at all |
| **Process flow** | The steps, in order, with the decision points named | Becomes `Process.xaml`'s dispatch and the leaf workflows |
| **Dispatcher / Performer split** | Dispatcher + Performer, Performer-only, or a single self-contained run | Drives which template(s) stage 2 fetches. Getting it wrong costs a re-scaffold |
| **Queue design** | Whether there is an Orchestrator queue, its name, and the `Reference` field's meaning | A Dispatcher and its Performer share **one byte-identical** queue name. A mismatch throws nothing: both jobs finish green and no transaction is processed |
| **Transaction types and their work-item columns** | Every type, and for each one every column it reads | **The gate.** Left to be discovered from the test data, `GetTransactionData` and `Process.xaml` get wired against a guess |
| **Config keys** | Every key, split across `Settings` / `Constants` / `Assets`, **for both TST and PRD** | A key that exists only in TST is a PRD run that fails on first read. See `references/config-format.md` |
| **Exception handling** | Which failures are **Business** (the application refused) and which are **Application** (technical), with the message text each one carries | `references/error-handling.md`. The split decides whether a transaction is retried or abandoned, so it is a design decision, not an implementation detail |
| **Test strategy** | How the process will be proved: which transaction types get a happy-path case, which refusals get a negative case, and what the acceptance evidence is | Stage 6 builds `Tests.xlsx` from this, and stage 7b/8 read the acceptance table back out of it. Without it, "tested" has no definition for this process |
| **Orchestrator assets required** | Every asset by **name, type and folder** — never a value | The `security` skill, `references/orchestrator-assets.md`. An asset nobody listed is an L4 run that fails on a credential nothing can resolve |
| **Decisions** | One row per decision: decision, answer, who confirmed, when | `references/decisions.md`. A decision nobody can trace gets re-litigated in review |
| **Open Questions / Assumptions** | Everything the PDD does not state | The alternative is a plausible default written as a fact, which is the single most expensive thing an SDD can do |

## Two decisions are asked at stage 1, not later

Both of them change what stage 2 fetches and what stage 3 wires, so a stage-1 SDD that leaves
them open blocks the next two stages rather than deferring work:

1. **The config file format** — stock `Config_<ENV>.xlsx`, or JSON. The JSON route requires
   rebuilding `InitAllSettings.xaml`; `references/config-format.md` has both.
2. **The credential mechanism** — Orchestrator Credential asset, the CyberArk PHI vault, or
   both. The `security` skill owns this.

Ask them **one at a time, in plain language**, and record both answers in the Decisions table
with who confirmed them. The other four decisions in `references/decisions.md` can wait for the
stage that needs them.

**A recommended default is not an answer.** Until a person confirms it, the decision stays an
Open Question and every placeholder it touches stays a placeholder.

## What must not appear in an SDD

- **An invented business rule.** If the PDD is silent on what the process should do, that is an
  Open Question. An SDD is the document people stop re-reading the PDD in favour of, so a guess
  written here becomes the requirement.
- **An invented credential name, selector or config value.** Same reason, and these get copied
  verbatim into `Config_*.xlsx` by the next stage.
- **A secret of any kind.** The SDD is a committed file. Asset names yes, asset values never.
