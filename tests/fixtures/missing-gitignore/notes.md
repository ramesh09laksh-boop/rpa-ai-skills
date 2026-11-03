# `missing-gitignore`

Without a `.gitignore`, Studio local state and `Exceptions_Screenshots/` get committed — and
those screenshots are of logged-in banking sessions, so this is a data-protection finding as
much as a tidiness one.

| | |
|---|---|
| `bad` | `fixture.json` removes the base `.gitignore` |
| `good` | the base `.gitignore` is present |