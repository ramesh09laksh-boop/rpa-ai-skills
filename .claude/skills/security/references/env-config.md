# Environment configuration

## There is no `.env` file

This estate does not use `.env` files, `config.json`, or environment variables for
application configuration. Configuration is an **Excel workbook per environment**:

```
Data/Config_TST.xlsx
Data/Config_PRD.xlsx
```

selected in `Main.xaml` from the entry-point argument:

```vb
' UC39
in_ConfigFile = "Data\Config_" + in_ENV + ".xlsx"
' TKB-UC11
in_ConfigFile = String.Format("Data\Config_{0}.xlsx", in_Env)
```

`in_ENV` / `in_Env` defaults to `TST` in all three projects. **Production is selected by the
Orchestrator process argument, not by the file.** A job started without arguments runs
against test — verify the argument on any PRD process.

The one environment variable in play is `isRemoteApp`, read by the Finnova library to detect
Citrix RemoteApp mode. It is set on the robot machine, not by the project. See
`.claude/skills/finnova-library/references/selector-model.md`.

## Workbook structure

Three sheets, read by `Framework/InitAllSettings.xaml`.

### `Settings` — `Name | Value | Description`

Environment-specific values that do not need to change without a redeploy.

```
OrchestratorQueueName                 CommissionAI_Queue
Finnova_System_PHI_Account_Name_ENT   Bposecbot@FinnovaEntris
Finnova_System_Win_Title_ENT          BRZ Entris*
Mail_System_Server                    https://webmail.swisscom.com
Mail_System_SharedMailbox             bas.boersenabrechnungen@swisscom.com
File_System_Folder_TraceLogs          D:\Data\RPA\BPO\UC39\Output\Trace Logs
AI_System_Credential                  AI_System_Authorization
```

Note what these are: queue names, **account names**, window titles, server URLs, mailbox
addresses, folder paths, and the *name of* a credential asset. **No passwords.**

### `Constants` — `Name | Value | Description`

Values identical across environments — framework tuning and log message fragments.

```
MaxRetryNumber                    0
ExScreenshotsFolderPath           Exceptions_Screenshots
LogMessage_GetTransactionData     Processing Transaction Number:
LogMessage_Success                Transaction Successful.
LogMessage_BusinessRuleException  Business rule exception.
LogMessage_ApplicationException   System exception.
```

TKB-UC11 adds `MaxConsecutiveSystemExceptions`, `RetryNumberGetTransactionItem`,
`RetryNumberSetTransactionStatus`, `ShouldMarkJobAsFaulted`,
`ExceptionMessage_ConsecutiveErrors`.

If a "constant" differs between `Config_TST` and `Config_PRD`, it belongs in `Settings`.

### `Assets` — `Name | Asset | OrchestratorAssetFolder | Description`

Values fetched from Orchestrator at job start; they **overwrite** any same-named setting or
constant. See `orchestrator-assets.md`.

```
Finnova_System_Launch_Cmd_ENT   Finnova_System_Launch_Cmd_ENT
Avaloq_System_Client_Path       Avaloq_SmartClient_Path
Mail_System_Exception_Cc        HITL_Mail_System_Exception_Cc
AI_System_Model                 AI_System_Model
```

## How much sits in Orchestrator varies a lot

| Project | Assets rows | Effect |
|---|---|---|
| UC39 | 10 | Launch commands, AI endpoint/model, recipient lists and one business rule are runtime-tunable |
| TKB-UC11 | 12 | Report keywords, SmartClient path/arguments, recipients, timings are runtime-tunable |
| **UC81** | **0 (sheet empty)** | Everything is baked into the committed workbook |

**UC81's `Assets` sheet is empty** — its Finnova launch command, SIX iD URL, customer id,
mail server and 19 exception messages all live in `Config_PRD.xlsx`. Changing any of them
requires editing and redeploying the package. Its only Orchestrator asset reads are two
inline `Get Asset` calls for the SIX account name.

This is a real divergence, not a style preference. For new work, follow the UC39/TKB-UC11
pattern: **anything an operator might need to change during an incident belongs in an
asset.**

## What goes where

| The value is… | Sheet | Why |
|---|---|---|
| Password, token, key | **none** — Credential asset or PHI vault | never in a workbook |
| Account or vault object *name* | `Settings` | an identifier, not a secret |
| Endpoint, launch path, report keyword, recipient list | `Assets` | changes without redeploy |
| Window title, mail folder, queue name | `Settings` | environment-specific, stable |
| Framework tuning, log text | `Constants` | identical across environments |
| Business rule a user should own | Camunda DMN | see `systems/camunda-system.md` |

## What must never be committed

Both `Config_TST.xlsx` and `Config_PRD.xlsx` **are** committed — that is the design, and it
works only because they contain no secrets. Keep it that way:

- **No passwords, tokens, API keys or connection strings with embedded credentials.**
- **No run output.** `Data/Output/` and `Data/Temp/` should contain only `placeholder.txt`.
  The reference projects violate this — `output_28thOct.txt`, `Strukis.txt`,
  `output_Analyze_1.txt`, `Tests/TestLog.txt` are all committed run artefacts.
- **No downloaded attachments.** `File_System_Folder_Download_*` points at the robot's data
  drive, outside the repo. Keep it that way.
- **No exception screenshots.** `Exceptions_Screenshots/` keeps its `placeholder.txt` only.

`Config_PRD.xlsx` does contain production mailbox addresses, folder paths, server names and
account names. That is accepted here, but it is still internal information — do not paste a
config sheet into a ticket, a test fixture or an external tool.

## Adding a config key

1. Choose the sheet using the table above.
2. Name it `<Application>_System_<Purpose>[_<Variant>]` — see
   `.claude/skills/standards/references/naming-conventions.md`.
3. Add it to **both** `Config_TST.xlsx` and `Config_PRD.xlsx`. A key present in only one
   fails at runtime in the other environment with a `KeyNotFoundException`, not at build time.
4. Fill the `Description` column — it is the only documentation these keys have.
5. If it is an asset, create it in Orchestrator in every environment before deploying.
6. Read it as `in_Config("<Name>").ToString`; pass `in_Config` down to sub-workflows rather
   than re-reading the file.

## Gaps

- **No schema validation.** A typo in a key surfaces as a runtime `KeyNotFoundException`
  deep in a transaction. Two such typos are already live and permanent
  (`Avaloq_System_Credendials`, `Finnova_System_PHI_Valut_Name`).
- **No check that `TST` and `PRD` have the same keys.** Worth adding to a build step.
- **Argument defaults duplicate config.** Several workflows carry hardcoded defaults in
  their `x:Class` attributes — e.g. `Finnova-Login.xaml` defaults
  `in_FinnovaLaunchCmd = "D:\finnova\novusprd\jureclient\cmd\start_finnova_jure.cmd"` and
  `in_ObjectName = "TAATERPA@FinnovaNovus"`, `Avaloq_Login.xaml` defaults
  `in_Avaloq_System_Client_Path` and the integration-server arguments. These are debugging
  conveniences that survive into production; they are **not secrets**, but they are stale
  production paths in source control. Prefer leaving defaults empty.
