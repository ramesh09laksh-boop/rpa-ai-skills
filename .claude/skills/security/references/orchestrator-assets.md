# Orchestrator assets and the CyberArk PHI vault

Everything here is taken from the three reference projects. Where a secret type has no
evidenced pattern, that is called out rather than filled in.

## How assets reach the workflow

`Framework/InitAllSettings.xaml` (stock REFramework, unmodified in all three projects)
builds one `Config` dictionary:

```
1  ReadRange "Settings" sheet   → Config(row("Name")) = row("Value")
2  ReadRange "Constants" sheet  → Config(row("Name")) = row("Value")
3  ReadRange "Assets" sheet     → for each row:
     TryCatch
       Get Orchestrator asset   AssetName     = row("Asset")
                                FolderPath    = row("OrchestratorAssetFolder")
                                CacheStrategy = None
       Config(row("Name")) = AssetValue
     Catch → Log Warn "Loading asset <Asset> failed: <message>"
```

Three consequences:

- **Assets overwrite settings and constants** of the same `Name`. The sheet header says so:
  *"Assets will always overwrite other config"*.
- **A missing asset is a warning, not a failure.** The workflow continues with the local
  value — or with nothing. If an asset is mandatory, assert on it after `InitAllSettings`;
  nothing does this today.
- `CacheStrategy=None` — values are read fresh each job.

Workflows read `in_Config("<Name>")` and **never** call `Get Asset` themselves. Pass
`in_Config` down; do not re-read the config file.

## Asset types in use

| Type | Activity | Evidenced use |
|---|---|---|
| **Credential** | `Get Credential` (`GetRobotCredential`) | `AVQ_Credential_1004` (Avaloq + CardOne + SMTP), `Bposecbot@Finnova*` (Finnova), `AI_System_Authorization` (API token) |
| **Text** | `Get Asset` (`GetRobotAsset`) | launch commands, report keywords, endpoints, model ids, recipient lists |
| **Integer** | `Get Asset` | `Tracelog_RotateInDays`, `Entsperren_QueueItem_Postpone_InHours` |
| **Bool** | — | **not evidenced.** No Bool asset appears in any of the three projects. |

`Get Credential` returns `Username` (String) + `Password` (**SecureString**). Keep the
password a `SecureString` — see `prohibited-practices.md`.

## Folder scoping

The `Assets` sheet has an `OrchestratorAssetFolder` column, passed to `Get Asset` as
`FolderPath`:

```
Get Orchestrator asset  AssetName  = row("Asset").ToString
                        FolderPath = row("OrchestratorAssetFolder").ToString
```

**The column is empty in every row of all three projects** — assets resolve in the robot's
default folder. The mechanism exists and is wired; it is simply unused. Populate it when a
process needs assets from a shared or tenant-level folder.

`OrchestratorQueueFolder` is a separate setting, also empty in all three.

## Naming conventions

### Config key → asset name

The `Name` column is the config key; the `Asset` column is the Orchestrator asset. They are
usually identical, but not always — the indirection lets one code base bind to
differently-named assets per tenant:

| Config `Name` | Orchestrator `Asset` |
|---|---|
| `Finnova_System_Launch_Cmd_ENT` | `Finnova_System_Launch_Cmd_ENT` |
| `Avaloq_System_Client_Path` | `Avaloq_SmartClient_Path` |
| `Avaloq_System_Client_Arguments` | `Avaloq_SmartClient_Arguments` |
| `Report_Search_Keyword` | `Report_Hauptprozess_Keyword` |
| `Mail_System_Exception_To` | `Email_Recipients_Error` |
| `Mail_System_Exception_Cc` | `HITL_Mail_System_Exception_Cc` |

### Key naming

```
<Application>_System_<Purpose>[_<Variant>]
```

Variant is the tower or system, so one code base serves several installations:

```vb
in_Config("Finnova_System_Launch_Cmd_"       + in_TOWER)
in_Config("Finnova_System_PHI_Account_Name_" + in_TOWER)
in_Config(String.Format("Mail_System_MailFolder_{0}", System))
```

Two live typos are load-bearing because the sheets contain them —
`Avaloq_System_Credendials` and `Finnova_System_PHI_Valut_Name`. Match the sheet; fix the
sheet and the code together or not at all.

### Per-machine assets

UC81 selects the SIX iD account per robot machine:

```vb
String.Format("{0}_UC81_SIX_System_AccountName", Environment.UserName)
"UC81_SIX_System_AccountName_Override"
```

A new runner needs its own asset created before it can log in. Use this pattern only when
accounts genuinely must differ per machine — it is easy to forget when provisioning.

## The CyberArk PHI vault

Used by the Swisscom projects (UC81 throughout; UC39 for mail).

Package: `Swisscom.PHI [1.0.7]`, activity `Get PHI Vault`.

```
' Logic/Logic-PHI_Vault_Get.xaml — the whole workflow
Get PHI Vault   ObjectName   = AccountName        ' e.g. "BPOSECBOT@FinnovaSB1"
                PHIEndpoint  = Obsolete           ' literal value in the sample
                UserName     = User
                Password     = Password           ' SecureString
```

Object names live in config, one per system:

| Config key | Object name |
|---|---|
| `Finnova_System_PHI_Valut_Name` *(sic)* | `BPOSECBOT@FinnovaSB1` |
| `Finnova_System_PHI_Account_Name_<TOWER>` | `Bposecbot@FinnovaEntris`, `TAATROPA@FinnovaNovus`, … |
| `Mail_System_PHI_Vault_Name` | `BPOSEC.Robotics` |
| `UBS_KeyTrader_PHI_Vault_Name` | `UBSKeyTrader@UC81` |
| `SIX_ID_System_PHI_Vault_Name_FIN` / `_AVQ` | `SMG3@SIXID` / `SMG2@SIXID` |

**The object name is an identifier, not a secret** — that is why it sits in a committed
config sheet.

### The Avaloq library's own CyberArk path

`Swisscom.UiPath.UIAutomation.Avaloq` ships a UI-driven CyberArk flow (`CyberArk/OpenPHI`,
`GetCyberArkAccount`, `ClosePHI`) that drives the SMCA portal in a browser. `GetCyberArkAccount`
returns `Username` (String), `Password` (SecureString) and `AccountDict`.

If you use it, **always call `ClosePHI` afterwards** — it leaves a browser session holding a
retrieved secret otherwise. The TKB-UC11 sample does not use this path; it uses an
Orchestrator credential instead.

## The two mechanisms are interchangeable by name

`UC39/Finnova_System/Finnova-Login.xaml` has the `Get PHI Vault` call **commented out**
(inside a `CommentOut` "Ignored Activities" block) and uses `Get Credential` instead — with
the asset name set to the *PHI account name* (`Bposecbot@FinnovaEntris`).

So: the Orchestrator credential asset is named after the CyberArk object. That makes
switching mechanisms a config change rather than a code change. Preserve the convention —
name a new credential asset after the vault object it mirrors.

## Choosing where a value goes

| The value is… | Put it in |
|---|---|
| A password, token or key | Orchestrator **Credential** asset (or CyberArk PHI vault) |
| An account/object *name* | `Settings` sheet |
| Environment-specific and changes without redeploy (endpoints, launch paths, report keywords, recipient lists) | `Assets` sheet → Orchestrator **Text** asset |
| Environment-specific but stable (window titles, mail folders) | `Settings` sheet, per `Config_<ENV>.xlsx` |
| Framework tuning (`MaxRetryNumber`, log messages) | `Constants` sheet |
| A business rule a user should change | Camunda DMN table — see `.claude/skills/standards/references/systems/camunda-system.md` |

## Gaps

- **No Bool asset is evidenced.** If you need one, `Get Asset` supports it, but there is no
  in-house example to copy.
- **No database connection string is evidenced** anywhere in the three projects. Avaloq's
  integration-server coordinates are the closest analogue and live in the Text asset
  `Avaloq_SmartClient_Arguments`. Follow that pattern — a whole connection string in one
  Text asset, or a Credential asset if it embeds a password — but note it is an extrapolation.
- **No asset is asserted as mandatory.** A missing asset logs a `Warn` and the job continues
  with an empty value, usually failing later with an unrelated error. Consider validating
  required keys immediately after `InitAllSettings`.
- **`PHIEndpoint = Obsolete`** is a literal string in `Logic-PHI_Vault_Get.xaml`. It appears
  to be a deprecated argument; confirm with the `Swisscom.PHI` package owner before copying
  it into new code.
