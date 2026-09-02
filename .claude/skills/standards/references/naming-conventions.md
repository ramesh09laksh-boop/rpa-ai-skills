# Naming conventions

Derived from the file and argument names actually used across the three reference projects.
Where the projects disagree, the majority/newest form is given as the rule and the
deviation is noted.

## Project & solution naming

```
<CustomerCode>-UC<NN>.<Description>
```

Hyphen after the customer/bank code, dot before the description. The description is
PascalCase words with no spaces; the UC number keeps the digits the business case was
issued with (`UC11`, not `UC011`).

| New project | Name |
|---|---|
| Credit-limit violations at TKB | `TKB-UC11.Kreditverletzung` |
| Manual stock-exchange orders at ZGKB | `ZGKB-UC39.ManuelleBoersenauftraege` |
| Securities master data at Entris | `ENT-UC81.Valoren` |

The customer code is the same tower/bank code used in config keys and window titles —
`ENT`, `ESP`, `ZGKB`, `PBS`, `NOVUS`, `TKB` (see `systems/finnova-system.md`). The Visual
Studio / UiPath solution folder, the repository name and the Orchestrator process name all
use this one form; do not vary it per system.

### Why the estate looks inconsistent

Three formats are live today, one per project:

| Existing folder | Format |
|---|---|
| `../Avaloq/TKB-UC11.Kreditverletzung` | `<CustomerCode>-UC##.<Description>` |
| `../Finnova/UC39_BPO_manuelle_Börsenaufträge` | `UC##_<Description>` |
| `../Finnova/PJFVA-966_UC81_BPO_VD03_TK _Valoren` | `<TicketID>_UC##_<Description>` |

**The TKB form above is the standard this repo proposes going forward** — confirm it with the
team once, see *Ask the team before standardising a new project's name* below. The other two
are historical — leave the existing folders alone; renaming them breaks Orchestrator process
links and deployed package names. Only new projects follow the rule.

Two things the old names show, which the standard avoids:

- No ticket ID in the folder name. `PJFVA-966` identifies the Jira ticket that requested
  the automation, not the automation — it goes stale the moment a second ticket touches
  the project.
- No spaces. `PJFVA-966_UC81_BPO_VD03_TK _Valoren` contains a stray space before `_Valoren`
  that has to be quoted in every path, script and `Invoke Workflow File` reference since.
  This one is checkable mechanically — see *No whitespace in `project.json` → `name`* below.

Umlauts: transliterate (`ManuelleBoersenauftraege`, not `ManuelleBörsenaufträge`). Workflow
file names inside the project still carry umlauts where the existing projects do — this
rule is about the project/solution/repository name only, which travels through build
agents, package feeds and URLs.

### Ask the team before standardising a new project's name

Three formats are live and the table above records which one to prefer, but **nothing in this
repo evidences who agreed that, or when** — it is a reading of the newest project, not a
minuted decision. Before naming a new UC project, put the convention to the team and get it
confirmed once:

> Existing UC projects use three different name formats (`TKB-UC11.Kreditverletzung`,
> `UC39_BPO_manuelle_Börsenaufträge`, `PJFVA-966_UC81_BPO_VD03_TK _Valoren`). We propose
> `<CustomerCode>-UC<NN>.<Description>` for everything new. Confirm, or tell us the form you
> want.

Then record the answer here and stop asking. Until it is recorded, use the TKB form — but say
that it is the proposal, not that it is settled.

### No whitespace in `project.json` → `name`

**Reject a stray space, tab, or any other whitespace anywhere in `project.json → name`.** Not
just leading or trailing — anywhere.

The value is not cosmetic. It propagates verbatim into:

- the published `.nupkg` file name,
- the package identity on the feed,
- the Orchestrator process name,
- every path, script and `Invoke Workflow File` reference that has to quote it afterwards.

`PJFVA-966_UC81_BPO_VD03_TK _Valoren` is the live example — one stray space before `_Valoren`
that has needed quoting in every path since. It cannot be fixed now without breaking the
Orchestrator process link, which is exactly why it has to be caught before the first publish.

The check is mechanical. Run it against `project.json`, `project.uiproj` and the folder name
before the first publish:

```powershell
$name = (Get-Content project.json -Raw | ConvertFrom-Json).name
if ($name -match '\s')                 { throw "project.json name contains whitespace: '$name'" }
if ($name -notmatch '^[A-Za-z0-9._-]+$') { throw "project.json name is not publishable: '$name'" }

# project.uiproj carries the same value under a capitalised key.
$uiName = (Get-Content project.uiproj -Raw | ConvertFrom-Json).Name
if ($uiName -ne $name) { throw "project.uiproj Name '$uiName' != project.json name '$name'" }
```

`\s` catches the tab and the non-breaking space (U+00A0) that a copy-paste out of Confluence
or an Excel cell introduces, neither of which is visible in a diff. The
`^[A-Za-z0-9._-]+$` test is the stricter one and the one to gate on.

### The templates fail this check on purpose

`templates/` ships `"name": "<PROJECT-NAME-TBD-ask-team>"`. That is whitespace-free, so it
passes the first test, and **deliberately fails the second** — the angle brackets make an
unreplaced placeholder impossible to publish and impossible to mistake for a finished value.

**Do not "fix" this by relaxing the regex or by softening the placeholder.** It is a
tripwire for the still-open naming decision above, in the same family as
`[UC-SPECIFIC — replace]` in the config workbooks. Replace the placeholder with the name the
team agreed; the check then passes on its own.

The placeholder is also deliberately *not* `CustomerCode-UCNN.Description`: that form is one
of the three formats live in the estate, and shipping it as the default would quietly answer
a question the team has not yet been asked.

Same rule, same reason, for the folder name and the repository name.

### Dispatcher/Performer pairs — undecided

**There is no working two-project (Dispatcher + Performer) pair in this estate yet.** With no
example to observe, a `_Dispatcher` / `_Performer` suffix convention would be an assumption,
so this repo does not have one and you should not invent one.

The first UC to instantiate both `templates/REFramework-Dispatcher-Base/` and a Performer
template settles it. Ask the team all three parts in one go — answering only the first leaves
the other two to drift:

1. **How should the two project names relate?** A shared stem with a role suffix, two separate
   UC numbers, something else?
2. **How are they packaged and published?** Two packages, or one package with two entry
   points?
3. **What queue name do they share?** The estate's own evidence is `UC<NN>_<Purpose>_Queue`
   (`UC11_Hauptprozess_Queue`, `UC14_Mahngebühr_Queue`, `UC15_KK_entsperren_Queue` in
   TKB-UC11's config sheets), but that is a single-project observation, not a pair convention.

Record the answer in this section, then apply it consistently from then on.

Whatever is decided for (1) and (2), (3) is load-bearing regardless: `OrchestratorQueueName`
must be **byte-identical** in the two projects' `Settings` sheets. A mismatch throws nothing —
the Dispatcher enqueues, the Performer polls a queue that does not exist or is empty, and both
jobs finish green with no work done. See
`templates/README.md#the-queue-name-is-a-contract-between-the-pair`.

## Workflow file names

```
<Application>-<Subject>_<Verb>.xaml
```

The **application prefix matches the folder**, and the verb goes **last** (German-influenced
word order — this is consistent across the estate).

| Folder | Examples |
|---|---|
| `Finnova_System/` | `Finnova-Valoren_Search.xaml`, `Finnova-Fee_Update.xaml`, `Finnova-System_Save.xaml`, `Finnova-Borsen_Abrechnungen_Extract.xaml` |
| `Avaloq_System/` | `Avaloq_Login.xaml`, `Avaloq_Ticket_bearbeiten.xaml`, `Avaloq_Navigator_Desk_Extract.xaml` |
| `SIX_ID_System/` | `SIX_iD_Instrument_Search.xaml`, `SIX_ID-Anlagefonds_Beschreibung_Get.xaml` |
| `CardOne_System/` | `CardOne_Login.xaml`, `CardOne_Page_Message_Check.xaml` |
| `Mail_System/` | `Mail-Process.xaml`, `Mail-Archiv_Move.xaml`, `Mail_Send.xaml` |
| `File_System/` | `File-Excel_Read.xaml`, `File-PDF_To_Text_File_Conversion.xaml`, `Tracelog_Append.xaml` |
| `Logic/` | `Logic-Get_Credential.xaml`, `Logic-Risikodomizil_Identification.xaml`, `Logic-CP_UBS_Extract.xaml` |
| `Camunda_System/` | `Camunda-Process_Logic.xaml` |
| `AI/` | `AI-Commission_Get_By_Text.xaml` |

### Separator

`-` after the application prefix, `_` inside the rest:
`Finnova-Borsen_Abrechnungen_Extract.xaml`.

Both `Finnova-` and `Finnova_` occur (`Finnova-Login.xaml` in UC39,
`Finnova_Login.xaml` in UC81). **Use `-` after the prefix** for new files; it is the
dominant form in the newest project.

### Common verbs

`_Get`, `_Search`, `_Extract`, `_Update`, `_Check`, `_Verify`, `_Fill`, `_Navigate`,
`_Close`, `_Save`, `_Send`, `_Move`, `_Read`, `_Process`, `_Login`, `_Logout`.

Prefer these over synonyms — `_Get` not `_Retrieve`, `_Check`/`_Verify` not `_Validate`.

### Prefixes with meaning

| Prefix | Meaning |
|---|---|
| `_` (leading underscore) | Developer scratchpad. Confined to `Tests/` and the Avaloq `Web_Nav_System/`. Never invoke from production code. |
| `Test-` / `_Test` | Test workflow. |

### Names to avoid

Two real files show what not to do:

- `Finnova-Get_BorsenPlatz_Nr.0b0d031ed918.xaml` — a Studio conflict artefact left in place
  (and a near-duplicate of `Finnova-BorsenPlatz_Nr_Get.xaml`, which also has the verb in the
  wrong position).
- `SIX_iD-Anlagefonds-AnteilscheinTrustShare (3)_Extract.xaml` — spaces and parentheses from
  a copied UI label.

Keep file names free of spaces, parentheses and hashes.

## Argument names

```
in_<Name>     input
out_<Name>    output
io_<Name>     in/out
```

Examples: `in_Config`, `in_TransactionItem`, `in_WinTitel`, `out_Status`, `out_ExtractDT`,
`io_KV_Auftragsnummer`, `io_PDFText`.

### Standard arguments

Use these exact names — sub-workflows are wired by name across the estate:

| Argument | Type | Meaning |
|---|---|---|
| `in_Config` | `Dictionary<String,Object>` | The config dictionary from `InitAllSettings`. Pass it down; never re-read `Config_*.xlsx`. |
| `in_TransactionItem` | `QueueItem` or `DataRow` | The current transaction. |
| `in_WinTitel` | `String` | Finnova window title for the current tower. *(Note the German spelling `WinTitel`, used consistently in UC39.)* |
| `in_TOWER` / `in_Tower` | `String` | Which Finnova installation. |
| `in_ENV` / `in_Env` | `String` | `TST` / `PRD`. |
| `in_System` | `String` | UC81 — `FIN` / `AVQ`. |

### Deviations to be aware of

Library activities do **not** use the `in_`/`out_` prefixes — they use bare PascalCase
(`WindowTitle`, `ExtractDataTable`, `ErrorMsg`). That is expected: the prefix convention
applies to **project workflows**, not to library activity arguments.

A few project workflows also use bare names (`Mail_Send.xaml` takes `MailTo`, `Subject`,
`Body`; `Finnova_System_Speichern.xaml` takes `WindowTitle`). Prefix new arguments anyway.

One real bug to avoid repeating: `Finnova_System-GP_Backoffice_Msg_Get.xaml` declares
`out_MeldungText` **as an in-argument**. If a caller gets nothing back from an `out_`
argument, check its direction.

## Config key names

```
<Application>_System_<Purpose>[_<Variant>]
```

`Finnova_System_Launch_Cmd_ENT`, `Finnova_System_Win_Title_ZGKB`,
`Mail_System_SharedMailbox_FIN`, `SIX_ID_System_URL`, `File_System_Folder_TraceLogs`,
`AI_System_Model`.

The variant suffix (tower or system) lets one code base serve several installations:

```vb
in_Config("Finnova_System_Win_Title_" + in_TOWER).ToString
in_Config(String.Format("Mail_System_MailFolder_{0}", System)).ToString
```

Build the key by concatenation with the variant, exactly as above.

Two live typos are load-bearing because the config sheets contain them —
`Avaloq_System_Credendials` (TKB-UC11) and `Finnova_System_PHI_Valut_Name` (UC81). Match the
sheet; fix both together or not at all.

## Log messages

`Log Message` with `Level=Info` for milestones, `Trace` for framework noise, `Warn` for
recovered failures. Include the identifier being processed:

```vb
String.Format("Move Archiv Mail Msg ID={0} System={1}", in_MsgId, System)
"KV_Auftragsnummer=" + KV_Auftragsnummer
```

Never log a credential, password or full connection string — see
`.claude/skills/security/references/prohibited-practices.md`.

## Variable names

`PascalCase`, no prefix (`WinTitel`, `RowCount`, `SysError`, `Exists`, `ExtractDT`).
`SysError` specifically is the retry-idiom sentinel — see `error-handling.md`.
