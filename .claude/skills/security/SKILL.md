---
name: security
description: Use whenever a workflow needs credentials, connection strings, API keys, or environment-specific configuration — before writing any UiPath activity that touches Orchestrator assets or config/.env files. Covers Get Credential / Get Asset patterns, the CyberArk PHI vault, the Config_TST/Config_PRD.xlsx Settings-Constants-Assets model, asset naming and folder scoping, SecureString handling, and what must never be hardcoded, logged or committed. Trigger on login workflows, API tokens, SMTP or Exchange authentication, database or integration-server connection parameters, and any new config key.
---

# Credentials, secrets and configuration

Two credential mechanisms are in use across this estate. Neither is wrong — **follow the one
the target project already uses.**

| Mechanism | Used by | How |
|---|---|---|
| **Orchestrator Credential asset** | TKB-UC11 (Avaloq, CardOne, SMTP), UC39 (Finnova, AI) | `Get Credential` → `Username` + `SecureString Password` |
| **CyberArk PHI vault** | UC81 (Finnova, SIX iD, UBS KeyTrader, Exchange) | `Swisscom.PHI` → `Get PHI Vault` (`ObjectName` → `UserName`, `Password`) |

Non-secret configuration lives in `Data/Config_<ENV>.xlsx`; anything that must differ per
environment without a redeploy lives in an Orchestrator **asset**.

## The three rules

1. **No secret ever appears in a `.xaml`, a config sheet, or a log.** Config holds the
   *name* of a credential (`AVQ_Credential_1004`, `Bposecbot@FinnovaEntris`), never its
   value.
2. **Passwords stay `SecureString` end to end.** Every library `Login` activity takes a
   `SecureString`. The `StringPassword` argument on both `Login` activities is a plaintext
   alternative — **do not use it.**
3. **Wrap every credential fetch in the standard retry idiom** — `RetryScope` 3 × 15 s with
   the `SysError` / `CheckTrue` pattern. Orchestrator and CyberArk both fail transiently.

## Canonical credential fetch

```
RetryScope  NumberOfRetries=3  RetryInterval=TimeSpan.FromSeconds(15)
  Body:
    Assign SysError = Nothing
    TryCatch
      Try:   Get Credential   AssetName     = in_CredentialName
                              CacheStrategy = None
                              Username      = out_User
                              Password      = out_Password     ' SecureString
      Catch: SysError = exception.Message ; exception = Nothing
  Condition: CheckTrue (Expression = "SysError is Nothing", ErrorMessage = SysError)
```

This is `UC39/Logic/Logic-Get_Credential.xaml` verbatim. Reuse that workflow rather than
re-implementing it. `CacheStrategy=None` is deliberate — a cached credential outlives a
rotation.

For an API token stored as a credential's password, unwrap only at the point of use:

```vb
new System.Net.NetworkCredential(String.Empty, AI_System_Authorization).Password
```

## Where the value must never go

Never put a secret in: a `.xaml` literal or argument default, `Config_*.xlsx`, a `Log
Message`, an exception message, a screenshot, a mail body, a trace log, or a commit.

`project.json` already masks logging in all five projects:

```json
"excludedLoggedData": [ "Private:*", "*password*" ]
```

That is a backstop, not permission — it only masks arguments whose *name* matches.

## References

- `references/orchestrator-assets.md` — asset types, `Get Asset` / `Get Credential`
  patterns, folder scoping, naming conventions, the CyberArk PHI vault
- `references/env-config.md` — `Config_TST/PRD.xlsx`, the Settings/Constants/Assets model,
  what belongs where, what must not be committed
- `references/prohibited-practices.md` — the explicit never-do list, with the real
  violations found in the reference projects
