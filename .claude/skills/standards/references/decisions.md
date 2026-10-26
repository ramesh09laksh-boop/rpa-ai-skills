# The decisions, in plain language

The skills say "ask the team" in several places. That is correct and it is not enough: someone
who is not a UiPath specialist does not know what the options are, what each one costs, or who
is supposed to answer.

So: one section per decision. What it is in a sentence, the options, what each one means later,
a **recommended default**, and who has to confirm it.

## How to use this file

**Ask one question at a time.** A list of five decisions gets one answer and four shrugs.

**A recommended default is not an answer.** Every default below is marked
*recommended, not decided*. Until a person confirms it, the decision stays an **Open Question**
in the SDD, and any placeholder it touches stays a placeholder. This is the tripwire that
already protects the project name: the templates ship
`"name": "<PROJECT-NAME-TBD-ask-team>"`, which fails the publishability check **on purpose**, so
an unanswered question cannot ship as an answer.

**Record every answer in the SDD's Decisions table** — decision, answer, who confirmed, when.
A decision nobody can trace gets re-litigated in review.

---

## 0. The platform — this estate is Automation Suite, not Automation Cloud

**Not a decision. A fact the skills must not get wrong**, listed first because everything below
assumes it.

This estate runs **UiPath Automation Suite** (self-hosted). It does **not** use Automation Cloud.
Projects execute on a **UiRobot** through an **Orchestrator folder** — for example
`Modern/RAP-Demo`.

**Skills and agents must not assume Cloud.** Concretely:

- The Orchestrator host is **your own** Automation Suite URL. It is not `cloud.uipath.com`, and
  no instruction should hard-code or imply that host.
- `uip login` targets it with **`--authority <url>`**. From the flag's own help text on this
  machine:

  > *Custom authority URL, e.g. `https://cloud.uipath.com` (default),
  > `https://govcloud.uipath.us` (Public Sector), **or your Automation Suite host**.
  > `https://` may be omitted*

  So: `uip login --authority <automation-suite-host> --tenant <tenant>`, plus
  `--client-id` / `--client-secret` for a non-interactive sign-in. Keep TST and production as
  separate **login profiles** (`uip login profiles list`, then `--profile <name>` on any
  command) so a command cannot hit the wrong one by default.
- Cloud-only features are **not available by assumption.** If a skill or an agent proposes one,
  that is a question for the team, not a step.
- The package feed is the one the **folder** uses. Do not assume a tenant-wide cloud feed.

### Record it per project, in the project's own `AGENTS.md`

Each UC project carries an **Environment** block so an agent does not have to infer any of this.
**Non-secret facts only** — names, hosts, paths and accounts; never a password, token, client
secret or connection string. Template and field meanings: the `uc-delivery` skill.

---

## 1. Config file format

**What it is.** Where the robot reads its settings — URLs, paths, queue names, timeouts — for
each environment.

| Option | What it means later |
|---|---|
| **`Config_TST.xlsx` / `Config_PRD.xlsx`** | Stock. Zero Framework changes. The whole estate works this way, so every other skill, rule and checker assumes it |
| `Config_TST.json` / `Config_PRD.json` | Requires **rebuilding `Framework/InitAllSettings.xaml`**, because `ReadRange` cannot read JSON. This is the one Framework file allowed to diverge from stock |

**Recommended default: the `.xlsx` pair** — *recommended, not decided*. It is the only
zero-migration-risk option and it matches every existing project.

It also decides something else, which is easy to miss: **the REFramework template version you
generate from.** 26.10.x ships the JSON-config `InitAllSettings`; 25.10.x ships the xlsx one.
Choose the template version to match, and never mix `Framework/` files across versions — see
the `project-scaffolding` skill, `references/generating-the-skeleton.md`.

**Who confirms:** the team's RPA lead. **Ask during PDD → SDD**, not at scaffolding time.
Detail: `config-format.md`.

---

## 2. Credential mechanism

**What it is.** How the robot gets the passwords it needs to sign in to the banking
applications.

| Option | What it means later |
|---|---|
| **Orchestrator Credential asset** | The estate's normal route. `GetAppCredential` against an asset named in the `Assets` sheet |
| CyberArk PHI vault | Used where the organisation requires vault-held credentials. Adds the `Swisscom.PHI` dependency |
| Both | Some applications via one, some via the other. Legitimate, but say which is which per application |

**Recommended default: the Orchestrator Credential asset** — *recommended, not decided*.

**Non-negotiable regardless of the answer:** no password in a `.xaml`, a config sheet, a test-data
workbook, a fixture `.json`, a log, an exception message, a screenshot, a prompt, or a commit.
That is not a decision; it is the `security` skill.

**Who confirms:** whoever owns the Orchestrator folder, plus security if the vault is in play.
The **asset must exist before `InitAllSettings` can resolve it** — a row for an asset nobody has
created fails Initialization, which is why `assets-parity` is a suppressible rule.

---

## 3. Orchestrator queue — yes or no

**What it is.** Whether work items pass through an Orchestrator queue between the part that
finds the work and the part that does it.

| Option | What it means later |
|---|---|
| **Dispatcher + Performer, sharing one queue** | The estate's standard shape. Retries, reporting and restart-after-failure come free from the queue |
| Performer only, no queue | **Three changes must be made together** to `GetTransactionData`, `MaxRetryNumber` and `OrchestratorQueueName`. Making one or two of the three produces a job that runs green and processes nothing |
| A single self-contained run | Fine for a genuinely one-shot process. Do not invent a Dispatcher a process does not need |

**Recommended default: queue-based Dispatcher + Performer** — *recommended, not decided* — if
the work arrives as a list of items. Otherwise say so explicitly.

**The trap, whichever way this goes:** `OrchestratorQueueName` must be **byte-identical** in both
projects' `Settings` sheets. A mismatch throws nothing — the Dispatcher enqueues, the Performer
polls a queue that is empty or does not exist, and both jobs finish green with no work done.

**Who confirms:** the RPA lead, from the process design in the PDD. Detail: the
`project-scaffolding` skill, `references/non-queue-reframework.md`.

---

## 4. Project name

**What it is.** The name in `project.json → name`, which becomes the published package name
**and** the Orchestrator process name.

**There is no default and this file will not invent one.** Three naming formats are live in the
estate and **none is minuted**. The repo's proposal, read off the newest project, is
`<CustomerCode>-UC<NN>.<Description>` — e.g. `TKB-UC11.Kreditverletzung` — and it is a proposal,
not a decision.

Constraints that hold whatever is chosen:

- **No whitespace anywhere.** It propagates verbatim into the package and process names.
- Must satisfy `^[A-Za-z0-9._-]+$`. The shipped placeholder deliberately does not.
- The same name lives in `project.json → name`, `project.uiproj → Name` **and** the folder name
  — rename all three together.
- Existing folders keep their historical names. Renaming breaks Orchestrator process links.

**Who confirms:** the team, once. Then record it and stop asking. Detail:
`naming-conventions.md`.

---

## 5. How a Dispatcher and Performer are named and published

**What it is.** When a UC needs both halves: how the two project names relate, how they are
packaged, and what queue they share.

**No default, and no observed pattern to copy** — there is no working Dispatcher + Performer
pair in this estate yet. A `_Dispatcher` / `_Performer` suffix rule would be an assumption, and
a scaffold must not quietly establish one.

Ask all three parts in one go, because the answers interact:

1. How should the two **project names** relate?
2. How are they **packaged and published** — two packages, or one with two entry points?
3. What **queue name** do they share?

Answer 3 matters regardless of 1 and 2, for the byte-identical reason in decision 3.

**Who confirms:** the RPA lead, on first occurrence. Record it in
`naming-conventions.md` (*Dispatcher/Performer pairs*) and apply it from then on.

---

## 6. Where the work items come from

**What it is.** The real upstream source — a mailbox, a share, a report, an API, a workbook
someone maintains.

**No default.** A test-data workbook is a **stand-in**, not an answer. On a real run this was
left as an Open Question while a `TestData.xlsx` carried the process, which is the right way to
keep moving — provided the question stays visibly open and is not quietly closed by the fixture.

Also settle, in the SDD and not from the test data:

- every **transaction type**, and the work-item columns each one reads
- whether work items **depend on each other** (item 3 editing what item 1 created). If they do,
  that is a constraint on the whole process, not a test-data detail
- what a **zero-item** run means: a genuinely idle day, or a failure

**Who confirms:** the business analyst who owns the process. Detail: `test-data.md` and
`wiring-the-framework.md`.

---

## Safety rails — not decisions, and not negotiable

Stated here because a non-expert has no way to know they are not up for discussion:

- **TST only. Never PRD** without named, explicit approval.
- **No real customer data** in a test run, a screenshot, a log or a commit.
- **Never type or paste a credential** into a prompt, a snapshot, a definition file or a chat.
- **Destructive actions only on throwaway data** you have been told is throwaway.
