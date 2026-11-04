# `byref-out-arg`

`TryParse` / `TryGetValue` called inside a VB expression. The Boolean result is correct but the
`out` variable is never assigned — it keeps its default — because an expression cannot write
back through a by-ref parameter. Nothing throws; the value is silently zero/empty.

| | |
|---|---|
| `bad` | `[Integer.TryParse(in_Reference, ParsedNumber)]` as an Assign value |
| `good` | `IsNumeric(...)` guard, with the conversion assigned separately |