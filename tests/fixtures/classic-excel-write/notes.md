# `classic-excel-write`

The classic `ui:AppendRange` / `ui:WriteRange` activities throw on a Windows (.NET 6) project —
*"Error in implicit conversion. Cannot convert null object"* at `WorkbookActivity.EndExecute` —
while `ReadRange` on the same workbook works, which is what makes it confusing.

| | |
|---|---|
| `bad` | `<ui:WriteRange>` |
| `good` | `<ui:WriteRangeX>` — the modern activity. Note the rule's `\b` means the `X` suffix is correctly not matched |