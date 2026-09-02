# `Mail_System/` — Exchange and SMTP

Mail is a system folder like any other, but it wraps **stock UiPath Mail activities**, not a
custom library. Present in all three reference projects — with two different transports.

## Two transports in the estate

| Project | Transport | Activities |
|---|---|---|
| UC39, UC81 (Swisscom) | Exchange Web Services | `ExchangeScope`, `GetExchangeMailMessages`, `SendExchangeMail`, `MoveMessageToFolder`, `DeleteMail` |
| TKB-UC11 (TKB) | SMTP + Exchange | `SendMail` (SMTP), `SendExchangeMail` |

Check the project's `Config_*.xlsx` before writing mail code — `Mail_System_Server`
(an HTTPS URL) means Exchange; `Mail_System_SMTP_Server` + `Mail_System_SMTP_Port` means SMTP.

## Configuration keys

### Swisscom (Exchange)

| Key | Value |
|---|---|
| `Mail_System_Server` | `https://webmail.swisscom.com` |
| `Mail_System_PHI_Account_Name` / `Mail_System_PHI_Vault_Name` | `BPOSEC.Robotics` |
| `Mail_System_SharedMailbox[_FIN\|_AVQ]` | shared mailbox address |
| `Mail_System_MailFolder_<System>` | source folder, e.g. `Posteingang` |
| `Mail_System_ArchivFolder_<System>` | `Posteingang\Archiv Robotics` |
| `Mail_System_Folder_<Counterparty>` | UC39 — `Trade Confirmations\UBS`, `…\Vontobel Neu`, … |
| `Mail_System_Mail_To`, `_Exception_To`, `_Info_Cc`, `_Exception_Cc` | recipients |
| `Mail_System_Exception_Template`, `_Info_Template` | `Data\Template\Exception.txt`, `Info.txt` |

### TKB (SMTP)

| Key | Value |
|---|---|
| `Mail_System_SMTP_Server` | `10.189.52.149` |
| `Mail_System_SMTP_Port` | `25` |
| `Mail_System_Autodiscover` | `Buddy1004.UiPath@tkb.ch` |
| `Mail_System_Info_To` | Orchestrator asset `Email_Recipients_Info` |
| `Mail_System_Exception_To` | Orchestrator asset `Email_Recipients_Error` |
| `Mail_System_Info_Template`, `_Info_Template_1`, `_Exception_Template` | `Data\Input\*.txt` |

Recipients are **Orchestrator assets** in TKB-UC11 and plain settings in the Swisscom
projects. Assets are the better choice — distribution lists change without a redeploy.

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
  `.claude/skills/security/references/prohibited-practices.md`.
- Mail addresses in config are business data, not secrets, but they are still PII — do not
  copy `Config_PRD.xlsx` into a ticket or a test fixture.
- `Mail-Delete.xaml` exists in UC81. Prefer `Mail-Archiv_Move.xaml`; deletion is not
  recoverable and the archive folder is the evidenced default.
