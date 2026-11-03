# `hardcoded-connection`

An `AssetName`, `Server` or `SharedMailbox` written as a literal in the XAML instead of read
from Config. It works, against whatever environment it names.

| | |
|---|---|
| `bad` | `AssetName="Acme_System_Credential"` |
| `good` | `AssetName="[in_Config(&quot;Acme_Credential_Asset&quot;).ToString]"` — the rule skips values that open with `[` |