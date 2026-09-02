# Prohibited practices

The never-do list. Each entry states the rule, then what the reference projects actually do —
including the places where they get it wrong, which are marked as **defects to fix, not
patterns to copy**.

---

## 1. Never hardcode a credential

**Never** put a password, token, API key or connection string with an embedded credential
into a `.xaml` literal, an argument default, or a config sheet.

✅ The estate is clean on this. Config holds only the *name* of a credential
(`AVQ_Credential_1004`, `Bposecbot@FinnovaEntris`, `AI_System_Authorization`); the value
comes from an Orchestrator Credential asset or the CyberArk PHI vault at runtime.

```
' RIGHT
Get Credential  AssetName = in_Config("Avaloq_System_Credendials").ToString
                Username  = User,  Password = Password      ' SecureString

' WRONG
Login  User = "BPOSECBOT",  StringPassword = "…"
```

---

## 2. Never use the `StringPassword` argument

Both library `Login` activities expose `StringPassword` (String) alongside
`Password` (SecureString). It exists for legacy callers.

**Do not use it.** A `String` password is visible in variable panels, logged arguments,
memory dumps and exception traces.

✅ Every login in all three projects passes `Password` as a `SecureString` and leaves
`StringPassword` as `{x:Null}`.

Unwrap a secret only at the moment of use, and only where the API demands a String:

```vb
' the one evidenced exception — an HTTP Authorization header
new System.Net.NetworkCredential(String.Empty, AI_System_Authorization).Password
```

Do not assign that to a variable; put it directly in the header argument.

---

## 3. Never log a credential value

No `Log Message`, `Write Line`, `Message Box`, mail body, trace log or exception message may
contain a password, token, or a connection string carrying one.

✅ Logging is safe throughout. Login workflows log only outcomes:

```vb
"Finnova Login Completed"
"Avaloq login was successful"
"SIX ID login was successful"
String.Format("CardOne User Exists={0}", Exists)
"Retry: Avaloq Login exception-" + exception.Message      ' message only, no credential
```

`project.json` masks logged arguments in all five projects:

```json
"excludedLoggedData": [ "Private:*", "*password*" ]
```

**That is a backstop, not permission.** It matches on argument *name* — a secret assigned to
a variable called `Token` is not covered.

⚠ Note `AI-Commission_Get_By_Text.xaml` logs the full API error body:

```vb
String.Format("AI API error: Status={0} Content:{1}", ResStat, ResTxt)
```

Safe only while the endpoint does not echo the Authorization header. Review before copying
this to another API.

---

## 4. Never put a secret in an exception message

Exception messages reach Orchestrator logs, mail templates and job history.

✅ Throws carry business context only:

```vb
Throw New BusinessRuleException(String.Format("Can't process: {0}", Message))
Throw New ApplicationException("SIX Login failed.")
```

Note the SIX iD throw says only that login failed — not which account or what was sent.
Keep that discipline.

---

## 5. Never commit run output, downloads or screenshots

`Data/Output/`, `Data/Temp/` and `Exceptions_Screenshots/` exist in source control **only**
to hold `placeholder.txt`.

❌ **Violated in the reference projects.** These are committed run artefacts:

| File | Project |
|---|---|
| `Data/Output/output.txt`, `output_28thOct.txt`, `output_29Oct_1.txt`, `output_Analyze_1.txt`, `Strukis.txt` | UC81 |
| `Tests/TestLog.txt` | UC81, UC39 |
| `Data/AI/FewShot_Temp.txt`, `Prompt_Temp.txt` | UC39 |

Fix by adding these paths to source-control ignores. Do not extend the pattern.

Downloaded attachments (`File_System_Folder_Download_*`) correctly live on the robot's data
drive, outside the repo — keep it that way. **No workflow cleans them up**; retention there
is unmanaged and worth flagging for any process that adds to it.

---

## 6. Never take a screenshot you would not send externally

`Framework/TakeScreenshot.xaml` captures the full screen of a logged-in banking session —
customer names, account numbers, balances.

- Keep `ExScreenshotsFolderPath` pointing at a controlled location. TKB-UC11 uses a network
  share (`P:\System_Daten\SCK\…\Prod\Exceptions_Screenshots`); the Finnova projects use a
  local relative path.
- Never attach a screenshot to a mail that leaves the organisation.
- Never commit one.
- `InformativeScreenshot` hashes are embedded in the `.xaml` by Studio at design time. Those
  are design-time captures of the developer's screen — check what was on it before
  committing a workflow authored against production data.

---

## 7. Never disable SSL verification

✅ `AI-Commission_Get_By_Text.xaml` sets `EnableSSLVerification=True`. Keep it.

⚠ `Camunda-Process_Logic.xaml` calls a public Azure endpoint over HTTPS with **no
authentication** — no headers, `ClientCertificate` and `ClientCertificatePassword` both
`Nothing`. Its payloads carry instrument attributes, not customer identifiers. Confirm that
is still true before adding a field, and flag the unauthenticated endpoint if you send
anything more sensitive.

---

## 8. Never send customer data to an unapproved external service

Two external egress points exist:

| Service | Sends | Where |
|---|---|---|
| `GoogleOCR` | page images of counterparty trade confirmations | `File-PDF_To_Text_File_Conversion.xaml` |
| AI chat endpoint | commission figures, currency, bank, Handelsgruppe | `AI-Commission_Get_By_Text.xaml` |

Both need explicit approval for the data they carry. `ReadPDFText` should be tried before
`GoogleOCR` — the project does this, and OCR is the fallback.

Before extending either, confirm what is in the payload. `FewShot_Examples.txt` is appended
to **every** AI system prompt and grows over time with "agent corrections" — review it
periodically for customer data that has leaked into an example.

---

## 9. Never use `MessageBox` in a workflow a robot runs

A modal dialog blocks an unattended robot indefinitely — the job hangs until it times out.

❌ **Violated twice:**

| File | Line |
|---|---|
| `Camunda_System/Camunda-Process_Logic.xaml` | `MessageBox (Text = JsonText)` — prints the full request body |
| `File_System/File-PDF_To_Text_File_Conversion.xaml` | `MessageBox` |

Remove both. Use `Log Message` at `Trace`. The Camunda one additionally dumps a request
payload to screen.

Likewise `Write Line` (`_Web_Nav_Table_Extract.xaml`) — use `Log Message`.

---

## 10. Never cache credentials

`Get Credential` and `Get Asset` both take `CacheStrategy`.

✅ Every call in the estate uses `CacheStrategy=None`. A cached credential outlives a
rotation and produces lockouts that are hard to diagnose. Keep it `None`.

---

## 11. Never leave a secret-bearing session open

`CyberArk/OpenPHI` opens a browser session against the SMCA portal holding a retrieved
secret. **Always call `CyberArk/ClosePHI` afterwards**, including on the failure path.

Similarly, `CardOne_Logout.xaml` is invoked from both `CloseAllApplications.xaml` and
`KillAllProcesses.xaml` — a browser session left open holds a server-side session. Follow
that for any authenticated web system.

⚠ Nothing closes UBS KeyTrader in UC81 — it is left running between jobs. Flagged in
`.claude/skills/standards/references/systems/ubs-keytrader.md`.

---

## 12. Never bake environment paths into argument defaults

Argument defaults set in Studio for debugging persist in the committed `.xaml`.

⚠ Live examples — not secrets, but stale production paths and account names in source
control:

```
Finnova-Login.xaml   in_FinnovaLaunchCmd = "D:\finnova\novusprd\jureclient\cmd\start_finnova_jure.cmd"
                     in_ObjectName       = "TAATERPA@FinnovaNovus"
                     in_TOWER            = "NOVUS"
Avaloq_Login.xaml    in_Avaloq_System_Client_Path = "C:\Program Files (x86)\AvaloqClient\TATG11\SmartClient.exe"
                     in_Avaloq_Systen_Arguments  = "-integrationServerHost sbttgavaint01.tgcorp.ch
                                                    -integrationServerPort 10023 -avaloqSystemId TATG11"
SIX_ID_Login.xaml    in_ObjectName = "SMG6@SIXID"   ' and this one disagrees with config
                                                     ' (SMG3@SIXID / SMG2@SIXID)
```

The last is the clearest argument for the rule: a default that has drifted out of sync with
config is worse than no default. Leave defaults empty and supply values from `in_Config`.

---

## Quick review checklist

Before committing a workflow that touches a secret:

- [ ] No password, token or key in any `.xaml`, config sheet or argument default
- [ ] `Password` is a `SecureString`; `StringPassword` unused
- [ ] Credential fetch wrapped in `RetryScope` 3 × 15 s with `CacheStrategy=None`
- [ ] No secret in any `Log Message`, exception message or mail body
- [ ] No `MessageBox`; no `Write Line`
- [ ] Nothing written to `Data/Output/`, `Data/Temp/` or `Exceptions_Screenshots/` is committed
- [ ] Any secret-bearing session (PHI, browser) is closed on both success and failure paths
- [ ] New external egress reviewed for what the payload actually contains
- [ ] New config key added to **both** `Config_TST.xlsx` and `Config_PRD.xlsx`
