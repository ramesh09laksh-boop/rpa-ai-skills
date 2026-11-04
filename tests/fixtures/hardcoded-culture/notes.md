# `hardcoded-culture`

A date parsed with a hardcoded `CultureInfo`. Excel cells stringify in the MACHINE's culture, so
a robot on a different locale parses the same workbook differently — or throws.

| | |
|---|---|
| `bad` | `New System.Globalization.CultureInfo("de-CH")` |
| `good` | `CultureInfo.InvariantCulture` |