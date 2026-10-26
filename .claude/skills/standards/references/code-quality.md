# The Workflow Analyzer gate

The analyzer is the one quality check in this estate that is **not** homegrown. `validate-project`
enforces our conventions; the analyzer enforces UiPath's, and it sees things no text rule can —
SecureString scope, serialization prerequisites, container usage, unreachable activities.

Everything below was verified by running it. `uip --version` → **1.204.0**, Studio rules
**2026.10**. Re-run `--help` before using a flag; the command surface changed recently (see the
`project-scaffolding` skill, `references/cli-command-map.md`).

## Running it

```bash
# Analyze a project against the rules shipped with the WorkflowCompiler
uip rpa analyze <project-dir>

# Analyze against a governance rule file  -- note BOTH extra requirements, below
uip rpa analyze <project-dir> \
  --governance-file-path "<ABSOLUTE path to the rules .json>" \
  --governance-file-type Studio \
  --detailed-log-path "<project-dir>/Documentation/analyzer-result.log"

# What the analyzer will actually apply to this project, before you write a line
uip rpa analyzer-rules list --project-dir <project-dir>
uip rpa analyzer-rules list --project-dir <project-dir> --scope Workflow
```

`uip rpa build` runs the analyzer by default and takes the same governance flags, plus
`--ignored-rules`. `--skip-analyze` turns it off — never pass that to get a build green.

**There is no `--result-path` and no `--stop-on-rule-violation` in this version.** Use
`--detailed-log-path`, or `--output json` and redirect. Read the exit code.

## Four traps, all observed

### 1. A relative `--governance-file-path` resolves against the *project*, not your shell

```
$ cd "00 - AI Skills"
$ uip rpa analyze REFramework-Dispatcher-Base --governance-file-path RuleConfigs/TAU.json ...
System.IO.DirectoryNotFoundException: Could not find a part of the path
'…\00 - AI Skills\REFramework-Dispatcher-Base\RuleConfigs\TAU.json'
```

**Always pass an absolute path.** This one at least fails loudly; the next three do not.

### 2. The default `--governance-file-type` is `AutomationOps`, and it is probably wrong for your file

Two different JSON shapes are both called "the rules file":

| Shape | `--governance-file-type` | What it is |
|---|---|---|
| `{ "Version", "Rules": [{ "RuleId", "IsEnabled", "ErrorLevel" }], "Counters" }` | `Studio` | Studio's own local rule config |
| An AutomationOps policy document | `AutomationOps` (**the default**) | A policy published from Automation Ops |

Passing a Studio-shaped file without `--governance-file-type Studio` crashes:

```
System.ArgumentNullException: Value cannot be null. (Parameter 'o')
   at UiPath.Analyzer.Shared.Governance.Services.AnalyzerRulesProcessor.ProcessRules[T](RoboticsOpsResponse response)
```

`--governance-file-type Default` **ignores your file entirely** — it says so, in one line that is
easy to scroll past:

```
[WARN] Governance file path '…' will be ignored when governance file type is Default
```

### 3. A signed-in tenant's policy silently outranks your file

From `--governance-file-path`'s own help: the tenant is asked first; where it publishes a policy,
**that** policy applies and your file *"is ignored with a warning"*.

So the only way to know which rule set ran is to read the log lines. The tell:

| In the output | Means |
|---|---|
| `[GovernancePolicyService] [ResolvePolicy] Connection info is incomplete … Analyzing with the rules shipped with the WorkflowCompiler.` | **No** governance file in effect |
| that line **absent**, no "will be ignored" warning | your file was consumed |

Check this before reporting a clean analyzer result. A clean result from the wrong rule set is
worth nothing.

### 4. `SC-` rules do not appear in the loaded rule set

`uip rpa analyzer-rules list` on a stock REFramework project returned **70 enabled rules**.
The prefixes present were `ST-`, `UI-` and `SY-`. **Not one `SC-` rule.**

This matters because the estate's candidate rule file enables 16 `SC-` rules, 10 of them at
**Error**. If those ids are not recognised by this Studio version, the file quietly applies 16
fewer rules than it appears to — the analyzer equivalent of a green run that did nothing.

**Before trusting any rule file, diff its enabled ids against what actually loads:**

```bash
uip rpa analyzer-rules list --project-dir <project> --output json > loaded.json
# then compare the RuleIds your file enables against the ids in loaded.json
```

## Reading the result

```json
"Summary": { "Critical": 0, "Error": 0, "Warning": 1, "Information": 0, "Verbose": 0 },
"Findings": [ { "Level", "ErrorCode", "RuleName", "Description",
                "WorkflowDisplayName", "ActivityDisplayName", "FilePath",
                "Recommendation", "DocumentationLink" } ]
```

`ErrorCode` is the rule id; `DocumentationLink` goes straight to the rule's page.

**Fix findings. Do not relax a rule to pass.** Disabling a rule to clear a finding converts a
visible problem into an invisible one, and the next person has no way to tell the difference
between "we considered this and it is fine" and "someone turned it off at 17:50 on a Friday".
If a rule genuinely does not apply, that is the same situation `validate-project.ignore`
handles: record the rule and the written reason, and keep the finding visible.

`ST-SEC-008` (SecureString scope) is the one that most often appears late — `uip rpa pack` runs
the analyzer and catches it, `uip rpa validate` does not. See `silent-failure-traps.md`.

## Where the rule file lives

**Open decision — not settled.** Three candidates sit outside this repo in `../RuleConfigs/`
(`TAU.json`, `RPA.json`, `Legacy.json`), and two questions are open: which is canonical, and
whether a client-specific rule set may be committed to this repo at all. Until that is answered,
point `--governance-file-path` at the team's file by absolute path.

What inspecting them turned up, for whoever decides:

| | TAU.json | RPA.json | Legacy.json |
|---|---|---|---|
| Rules | 100 | 99 | 99 |
| Enabled | 37 (21 Error, 16 Warning) | 37 (21 Error, 16 Warning) | 33 (20 Error, 13 Warning) |

- `TAU.json` carries a **malformed entry**: `{"RuleId": "false", "IsEnabled": false, …}` at index
  98. That is the 100th "rule" and it is a corrupted edit, not a rule. `RPA.json` does not have it.
- TAU and RPA differ on exactly four rules — `ST-ANA-006`, `ST-DBP-007`, `SC-DBP-004`,
  `SC-REL-003` — in enablement or severity. Nothing records why.
- Applying `TAU.json` with `--governance-file-type Studio` **did** change the outcome against a
  stock REFramework (0 findings with `Default`, 1 with TAU), so the file is consumed. But the
  rules it enables produced no findings on a 16-workflow project, and `ST-USG-034` — which the
  file marks `IsEnabled: false` — **fired anyway**. The mapping between this file's fields and
  the rules actually applied is **not established**. Settle that before the file is treated as a
  gate rather than a suggestion.

Once the file is agreed, ship it inside a skill (`assets/`) so it travels with
`npx skills add`; a file under `templates/` or the repo root does not reach UC projects.

## When the gate applies

| Stage | Requirement |
|---|---|
| Code Review | `uip rpa analyze` run; every finding triaged, none suppressed silently |
| UAT Readiness | Clean analyzer result, plus L4 on the evidence ladder |
| Definition of Done | Both of the above, with the command and the rule set named |
