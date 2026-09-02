# `AI/` — LLM chat-completion endpoint

An HTTP integration with a chat-completion model, used by
`UC39_BPO_manuelle_Börsenaufträge` to derive commission adjustments from free-text
backoffice messages that rule-based parsing could not handle.

> The folder is named `AI/`, not `AI_System/`, even though its config keys are
> `AI_System_*`. New folders should use the `_System` suffix — see `../naming-conventions.md`.

One workflow: `AI-Commission_Get_By_Text.xaml`.

## Configuration

| Key | Source | Value |
|---|---|---|
| `AI_System_Credential` | Settings | `AI_System_Authorization` — the name of the credential asset |
| `AI_System_Model_Chat_EndPoint` | **Orchestrator asset** | chat completions URL |
| `AI_System_Model` | **Orchestrator asset** | model id |
| `File_System_AI_System_Prompt` | Settings | `…\Input\AI\SystemPrompt_Commission.txt` |
| `File_System_AI_User_Prompt` | Settings | `…\Input\AI\UserPrompt_Commission.txt` |
| `File_System_AI_Prompt_Temp` | Settings | `…\Input\AI\Prompt_Temp.txt` — the request-body template |
| `File_System_AI_FewShot_Examples` | Settings | `…\Input\AI\FewShot_Examples.txt` |
| `File_System_AI_FewShot_Temp` | Settings | `…\Input\AI\FewShot_Temp.txt` |

Endpoint and model are **assets**, so the model can be changed without a redeploy. The
credential asset name is a setting pointing at the credential.

## Prompts live in files, not in the workflow

```
Prompt_Temp.txt            request body skeleton with $model, $system_prompt, $user_prompt
SystemPrompt_Commission.txt system instructions
UserPrompt_Commission.txt   user message with $BASE_EIGENE, $BASE_FREMDE,
                            $EBANKING_TARIFF, $CURRENCY, … placeholders
FewShot_Examples.txt        accumulated corrections, appended to the system prompt
```

Assembly:

```vb
Txt = Prompt_Temp.Replace("$model", in_Config("AI_System_Model").ToString) _
               .Replace("$system_prompt", Newtonsoft.Json.JsonConvert.ToString( _
                    System_Prompt & vbCrLf & vbCrLf & _
                    "### LEARNED EXAMPLES (agent corrections)" & vbCrLf & FewShot))

User_Prompt = User_Prompt.Replace("$BASE_EIGENE", …).Replace("$EBANKING_TARIFF", …)…
Txt = Txt.Replace("$user_prompt", Newtonsoft.Json.JsonConvert.ToString(User_Prompt))
```

**`JsonConvert.ToString` does the escaping.** Never concatenate prompt text into JSON
without it — a quote or newline in a Finnova message otherwise breaks the request body.

To change model behaviour, edit the prompt files — not the workflow.

## The call

```
RetryScope  NumberOfRetries=3  RetryInterval=TimeSpan.FromSeconds(15)
    Get Credential (AssetName = in_Config("AI_System_Credential"))  → AI_System_Authorization
    ' password field only — the token is stored as the credential's password

HttpClient "HTTP Request AI Chat"
    Method               = POST
    EndPoint             = in_Config("AI_System_Model_Chat_EndPoint")
    Body                 = Txt
    BodyFormat           = application/json
    AcceptFormat         = ANY
    AuthenticationType   = None
    EnableSSLVerification= True
    TimeoutMS            = 60000
    Headers:
        Authorization = new System.Net.NetworkCredential(String.Empty, AI_System_Authorization).Password
        SCS-Version   = 1.0
        Content-Type  = application/json
    → Result = ResTxt, StatusCode = ResStat
```

Two details worth reusing:

- **The API token is stored as a credential asset's *password*** and unwrapped at the point
  of use with `new NetworkCredential(String.Empty, secure).Password`. It stays a
  `SecureString` everywhere else. Do this for any bearer token — see
  `.claude/skills/security/references/orchestrator-assets.md`.
- **`EnableSSLVerification=True`** and a 60 s timeout. Keep both.

## Response handling

```vb
If ResStat = 200 Then
    DeserializeJson(ResTxt) → jsonObj
    DeserializeJson(jsonObj("choices")(0)("message")("content").ToString) → jsonObj
    out_Commision_Eigene_Adjust      = jsonObj("eigene").ToString
    out_Commision_Fremde_Adjust      = If(jsonObj("fremde") Is Nothing OrElse
                                          jsonObj("fremde").Type = JTokenType.Null,
                                          "", jsonObj("fremde").ToString.Trim)
    out_Confidence                   = jsonObj("confidence").ToString
    out_Rule_Applied                 = jsonObj("rule_applied").ToString
    out_Commision_Eigene_Prozentsatz = If(jsonObj("prozentsatz") Is Nothing OrElse …, "", …)
Else
    out_Confidence = "low"
    Log Info String.Format("AI API error: Status={0} Content:{1}", ResStat, ResTxt)
End If
```

The model's answer is a **JSON string inside** the chat content, so it is deserialised
twice. Null-guard every optional field with the `Is Nothing OrElse … .Type = JTokenType.Null`
test — the model omits fields rather than returning nulls.

## The confidence contract

The model returns `confidence` and `rule_applied` alongside its answer, and a failed call
degrades to `confidence = "low"` rather than throwing. **The caller decides what to do with
low confidence** — the AI workflow never books anything itself.

Keep this shape for any new AI step:

- return a confidence signal, never just an answer
- degrade to low confidence on error instead of throwing
- have the caller route low confidence to a human (in UC39, via `Mail-Process.xaml`)
- return `rule_applied` so a reviewer can see *why*

## Cautions

- **Model output is never trusted directly.** It adjusts a commission figure that is then
  written to Finnova by a separate, deterministic workflow. Do not let a model response
  drive an irreversible action without a confidence check.
- **Prompts carry business data.** `UserPrompt_Commission.txt` is filled with commission
  figures, currency, bank and Handelsgruppe. Confirm the endpoint is an approved internal
  service before sending anything containing customer identifiers.
- **`FewShot_Examples.txt` grows over time** with "agent corrections" and is appended to
  every system prompt. It is unbounded and uncurated — review it before it silently becomes
  the dominant part of the prompt.
- **The status code is checked but the error is only logged at `Info`.** A persistently
  failing endpoint produces low-confidence results and Info-level noise, not an alert.
  Consider `Warn` at minimum.
