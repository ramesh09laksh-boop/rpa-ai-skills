# `Mail_System/` — Exchange and SMTP

<!-- maintainer-provenance: this file's content is derived from the estate's own library and
     sample projects, which sit one level above the rpa-ai-skills repo on a maintainer's
     machine. Every `../Finnova/...`, `../Avaloq/...`, `../REFramework-*/` and `templates/...`
     path below is cited so a claim can be traced back to where it was read. NONE of them is
     delivered by `npx skills add` and none will resolve in your project. The install-simulation
     lint honours this marker for the whole file; see lint-skills.ps1 .NOTES. -->

> **Provenance: Legacy samples.** The `UC39`, `UC81` and `TKB-UC11` projects cited below are
> `targetFramework: Legacy` (`modernBehavior: false`, Studio 20.10–21.10). They are **evidence of
> what the estate does**, not conformance targets. Modern equivalent: the REFramework templates (maintainer provenance -- `templates/` lives in the rpa-ai-skills repo, not in your project; the `project-scaffolding` skill fetches one)
> (Windows / `modernBehavior: true`, Studio 23.10.8.0), plus `wiring-the-framework.md` in the
> `standards` skill. Folder layout and the `_System`/`Logic` split carry over
> unchanged; `project.json` values, activity choices and `Framework/` internals do not.

Mail is a system folder like any other, but it wraps **stock UiPath Mail activities**, not a
custom library. Present in all three reference projects — with two different transports.

## Two transports in the estate

| Project | Transport | Activities |
|---|---|---|
| UC39, UC81 (Swisscom) | Exchange Web Services | `ExchangeScope`, `GetExchangeMailMessages`, `SendExchangeMail`, `MoveMessageToFolder`, `DeleteMail` |
| TKB-UC11 (TKB) | SMTP + Exchange | `SendMail` (SMTP), `SendExchangeMail` |

Check the project's `Config_*.xlsx` before writing mail code — a populated `Mail_System_Server`
(an HTTPS URL) means Exchange; a populated `Mail_System_SMTP_Server` + `Mail_System_SMTP_Port`
means SMTP.

## Configuration keys

**Keys and shapes only — the values live in `Config_<ENV>.xlsx` and in Orchestrator assets.**
This file deliberately records *which key to read* and *what shape of value it holds*, never a
host, mailbox, vault object or address. A skill ships to every install and into every agent's
context, so a real hostname or mail address written here is published to all of them, and it goes
stale besides: the authority is the workbook in front of you. Read the value at runtime through
`in_Config`; read it at design time out of your own project's workbook.

### Exchange transport

| Key | What it holds | Where the value comes from |
|---|---|---|
| `Mail_System_Server` | Exchange Web Services endpoint (an HTTPS URL) | `Config_<ENV>.xlsx` → `Settings` |
| `Mail_System_PHI_Account_Name` / `Mail_System_PHI_Vault_Name` | CyberArk PHI vault **object name** — an identifier, not a secret | `Config_<ENV>.xlsx`; the password comes from the vault |
| `Mail_System_SharedMailbox[_FIN\|_AVQ]` | shared mailbox address the robot authenticates to | `Config_<ENV>.xlsx` → `Settings` |
| `Mail_System_MailFolder_<System>` | source folder name, e.g. the inbox | `Config_<ENV>.xlsx` |
| `Mail_System_ArchivFolder_<System>` | archive folder the workflow moves mail to on success | `Config_<ENV>.xlsx` |
| `Mail_System_Folder_<Counterparty>` | one folder per counterparty, keyed by name | `Config_<ENV>.xlsx` |
| `Mail_System_Mail_To`, `_Exception_To`, `_Info_Cc`, `_Exception_Cc` | recipients | prefer an Orchestrator **Text asset** — see below |
| `Mail_System_Exception_Template`, `_Info_Template` | path to a body template under `Data\Template\` | `Config_<ENV>.xlsx` |

### SMTP transport

| Key | What it holds | Where the value comes from |
|---|---|---|
| `Mail_System_SMTP_Server` | SMTP relay host | `Config_<ENV>.xlsx` → `Settings`. **Never hardcode it in a workflow** — `validate-project`'s `hardcoded-connection` rule fires on `Server="…"` |
| `Mail_System_SMTP_Port` | SMTP port | `Config_<ENV>.xlsx` → `Settings` |
| `Mail_System_Autodiscover` | the sending account's address, used for autodiscover | `Config_<ENV>.xlsx` → `Settings` |
| `Mail_System_Info_To` | info recipients | Orchestrator Text asset — the key's value is the **asset name**, e.g. `Email_Recipients_Info` |
| `Mail_System_Exception_To` | exception recipients | Orchestrator Text asset, e.g. `Email_Recipients_Error` |
| `Mail_System_Info_Template`, `_Info_Template_1`, `_Exception_Template` | paths to body templates under `Data\Input\` | `Config_<ENV>.xlsx` |

**Asset names are identifiers and belong here; their values do not.** That is the same split the
`security` skill applies to credentials: naming `Email_Recipients_Error` tells you what to wire
up, and tells you nothing you should not know.

Recipients are **Orchestrator assets** in the SMTP project and plain settings in the Exchange
ones. Assets are the better choice — a distribution list changes without a redeploy, and the
address never enters a committed file.

## The Exchange read pattern

From `UC81/Mail_System/Mail-Archiv_Move.xaml` — reuse verbatim:

```
System = in_Config("System").ToString                    ' "FIN" or "AVQ"
Logic\Logic-PHI_Vault_Get.xaml (AccountName = in_Config("Mail_System_PHI_Vault_Name"))
                                                          → User, Password

RetryScope  NumberOfRetries=3  RetryInterval=TimeSpan.FromSeconds(30)
  TryCatch
    Try:  Assign SysError = Nothing
          GetExchangeMailMessages
            Server             = in_Config("Mail_System_Server")
            AuthenticationMode = UserNameAndPassword
            User = User,  SecurePassword = Password
            ExchangeVersion    = Exchange2010_SP2
            SharedMailbox      = in_Config(String.Format("Mail_System_SharedMailbox_{0}", System))
            CustomFolder       = in_Config(String.Format("Mail_System_MailFolder_{0}", System))
            MailFolder         = Calendar          ' ignored when CustomFolder is set
            FilterByMessageIds = { in_MsgId }
            Top = 1,  MarkAsRead = False,  GetAttachements = False,  OnlyUnreadMessages = False
    Catch: SysError = exception.Message ; exception = Nothing
  Condition: CheckTrue (SysError is Nothing)
```

Details that matter:

- **`ExchangeVersion = Exchange2010_SP2`** throughout. Do not change it without testing —
  the server negotiates down.
- **`MailFolder = Calendar` is a placeholder.** When `CustomFolder` is set, `MailFolder` is
  ignored. It looks like a bug; it is not.
- **`MarkAsRead = False`** — the workflow must be re-runnable. Mails are moved to an archive
  folder on success instead of being marked read.
- Mail retry uses **30 s** intervals, not the 15 s used elsewhere.
- The mailbox is a **shared mailbox**; the robot's own account authenticates to it.

## Workflow inventory

### UC81

| Workflow | In |
|---|---|
| `Mail-Archiv_Move` | `in_Config`, `in_MsgId` |
| `Mail-Delete` | `in_Config`, `in_MsgId` |
| `Mail-_Process_Exception` | `in_Config`, `in_ExceptionNr` (Int32), `in_ExceptionMsg`, `in_TransactionItem` |

### UC39

| Workflow | In |
|---|---|
| `Mail-Process` | `in_Config`, `in_Typ`, `in_Msg`, `in_Tower`, `in_TransactionItem` |

`in_Typ` switches recipients: `"Info"` → `Mail_System_Mail_To` + `Mail_System_Info_Cc`;
`"Exception"` → `Mail_System_Exception_To` + `Mail_System_Exception_Cc`.

### TKB-UC11

| Workflow | In |
|---|---|
| `Mail_Send` | `MailTo`, `Subject`, `Body`, `in_Config` |
| `Mail_Info_Process` | `in_Config`, `in_Type`, and 11 `in_KV_*` business fields |
| `Mail_Exception_Process` | `in_Config`, `in_Type`, `in_SystemException` (Exception) |

`Mail_Send.xaml` fetches the SMTP credential itself
(`Get Credential`, AssetName = `in_Config("Avaloq_System_Credendials")`) inside the standard
3 × 15 s retry scope.

## Templates

Bodies come from text files, not inline strings:

```
ReadTextFile (FileName = in_Config("Mail_System_Exception_Template"))
' then substitute placeholders
```

Add new templates under `Data/Template/` (UC39) or `Data/Input/` (UC81, TKB-UC11) and
reference them through config. Never build a mail body inline in a workflow.

## Mail as a business-exception channel

UC81 uses mail **instead of** throwing `BusinessRuleException`. `Mail-_Process_Exception.xaml`
takes a numbered `in_ExceptionNr` that indexes into config:

```
Exception_1_Msg   Instrument in SIX iD nicht gefunden
Exception_3_Msg   Instrumententyp in SIX iD unbekannt
Exception_9_Msg   Fehlender Börsenplatz
Exception_14_Msg  Status Valor prüfen, kann nicht eröffnet werden.
…19 in total
```

The queue item stays successful and a human is mailed. UC39 and TKB-UC11 throw instead.
**Pick one convention per project.** If you add an exception message to UC81, add it to
both `Config_TST.xlsx` and `Config_PRD.xlsx` with the same number.

## Cautions

- **Never log mail credentials.** `Mail_System_PHI_Account_Name` is an identifier; the
  password from the vault must not reach a log or an exception message. See
  the `security` skill, `references/prohibited-practices.md`.
- Mail addresses in config are business data, not secrets, but they are still PII — do not
  copy `Config_PRD.xlsx` into a ticket or a test fixture.
- `Mail-Delete.xaml` exists in UC81. Prefer `Mail-Archiv_Move.xaml`; deletion is not
  recoverable and the archive folder is the evidenced default.
