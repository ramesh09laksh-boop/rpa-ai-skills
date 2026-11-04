# `secret-argument-string`

A password/secret/token-named argument typed `String` rather than `SecureString`. Analyzer rule
`ST-SEC-009` calls the cast a security breach, and a plaintext secret must not cross a workflow
boundary at all.

| | |
|---|---|
| `bad` | `in_Password` as `InArgument(x:String)` |
| `good` | `in_Password` as `InArgument(s:SecureString)` |

The rule has two carve-outs it must keep: an argument named `*Credential*` (this estate names
those after the Orchestrator ASSET, which is legitimately a String) and any argument passed to
`AssetName=`. Neither is exercised here; both are load-bearing on real estate code.