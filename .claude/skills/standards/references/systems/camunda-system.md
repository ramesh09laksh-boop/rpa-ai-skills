# `Camunda_System/` — Camunda DMN decision service

An HTTP integration, not a UI one. Camunda hosts the **business decision tables** (DMN) that
UC81 uses to map SIX iD values onto Finnova values. Present in
`PJFVA-966_UC81_BPO_VD03_TK _Valoren` — one workflow.

Externalising these mappings into DMN means a business user can change a rule without a
robot redeploy. Prefer adding a decision table over hardcoding a mapping in `Logic/`.

## Endpoint

```
https://rpa-camunda.azurewebsites.net/engine-rest/decision-definition/key/<DECISION_KEY>/evaluate
```

Example key: `UC81_TK_Valoren_GetNastroCode`.

The endpoint is passed in as `in_EndPoint` — it is **not** in `Config_*.xlsx`. Callers
build it, and the default sits in the workflow's own argument default. That is a gap: the
host name is effectively hardcoded across callers. Move it to config if you extend this.

## The single workflow — `Camunda-Process_Logic.xaml`

| Arg | Dir | Type | Notes |
|---|---|---|---|
| `in_JSONFile` | in | String | Request-body template, e.g. `Data\Input\GetNastroCode_JSON.txt` |
| `in_EndPoint` | in | String | Full evaluate URL |
| `in_ArrayOfValue` | in | String[] | Values substituted into the template, in order |
| `in_ResultKey` | in | String | Which output variable to read back, e.g. `NostroFinnova` |
| `out_Result` | out | String | The decision value |

Body:

```
ReadTextFile (in_JSONFile) → JsonText

ForEach item In in_ArrayOfValue  (CurrentIndex = Index)
    JsonText = JsonText.Replace(String.Format("value({0})", Index), item)

MessageBox (Text = JsonText)                    ' ⚠ see below

HttpClient
    Method      = POST
    EndPoint    = in_EndPoint
    Body        = JsonText
    BodyFormat  = application/json
    AcceptFormat= JSON
    TimeoutMS   = 6000
    → Result

DeserializeJson (Result) → JsonArray
out_Result = JsonArray.Item(0)(in_ResultKey)("value").ToString
```

### The template substitution scheme

Request bodies live in `Data/Input/*.txt` with positional placeholders `value(0)`,
`value(1)`, … replaced from `in_ArrayOfValue` by index:

| Template | Decision |
|---|---|
| `GetNastroCode_JSON.txt` | Nostro / balance code |
| `GetKategorie_JSON.txt` | Category |
| `GetRisikodomizil_JSON.txt` | Risk domicile |
| `GetTrustType_JSON.txt` | Trust type |
| `GetZusatzregel_JSON.txt` | Supplementary rule |

To add a decision: add a template to `Data/Input/`, publish the DMN table in Camunda, and
call this workflow with the new key. No new workflow is needed.

### Response shape

Camunda returns an array of result objects; the workflow reads the **first** row only:

```vb
JsonArray.Item(0)(in_ResultKey)("value").ToString
```

A DMN table with `hitPolicy` allowing multiple matches will silently lose all but the first
result. Confirm the table's hit policy is single-result before relying on this.

## Defects in this workflow — fix, don't copy

- **`MessageBox` before the HTTP call.** A modal dialog blocks an unattended robot
  indefinitely. This is a leftover debug aid and must be removed before this workflow runs
  in production. The proper `Log Message` calls beside it are commented out.
- **No `TryCatch` and no `RetryScope`.** Every other remote call in the estate is wrapped in
  the standard `RetryScope` 3 × 15 s + `SysError` idiom (see `../error-handling.md`).
  This one is not — an HTTP hiccup becomes an unretried system exception.
- **`TimeoutMS = 6000`** is short for a cold Azure App Service. Combined with no retry, a
  cold start fails the transaction.
- **No status-code check.** A non-200 response goes straight into `DeserializeJson`.

If you touch this workflow, wrap it in the standard retry idiom and delete the `MessageBox`.

## Position in the transaction

Called from `Logic/` mapping workflows — `Logic-Bilanzcode_Nostro_Finnova_Get.xaml`,
`Logic-Risikodomizil_Finnova_Get.xaml`, `Logic-Risikotitelart_Finnova_Get.xaml`,
`Logic-Kurztext_And_Risikodomizil_Finnova_Get.xaml` — which sit between SIX iD extraction
and the Finnova write.

```
SIX_iD-*_Extract  →  Logic-*_Finnova_Get  →  Camunda-Process_Logic  →  Finnova-*_Process
```

## Security

The endpoint is a public Azure host reached over HTTPS with **no authentication** evidenced
in the workflow (no headers, no client certificate — `ClientCertificate` and
`ClientCertificatePassword` are both `Nothing`).

The request bodies carry instrument attributes, not customer identifiers. Confirm that is
still true before adding a field to a template, and flag the unauthenticated endpoint if
your process sends anything more sensitive. See `.claude/skills/security/`.
