# A fetched template differs on every text file — that is line endings

A fetched template will differ from the source in `rpa-ai-skills` on **every text file** if you
diff it naively:

```
$ diff -r rpa-ai-skills/templates/REFramework-Dispatcher-Base ./REFramework-Dispatcher-Base
   ... every .md, .json and .uiproj reported as changed
```

**That is line endings, not content.** Git's `core.autocrlf` normalises LF to CRLF on checkout
on Windows, so the fetched copy is CRLF where the repo stores LF.

Confirm it before chasing it — both commands settle it in seconds:

```bash
diff -r --strip-trailing-cr <source> <fetched>   # exits clean if only line endings differ
md5sum <source>/Data/Config_TST.xlsx <fetched>/Data/Config_TST.xlsx   # binaries are untouched
```

Verified on the real repo: content identical, all three `.xlsx` workbooks match by md5.

## Nothing to fix — for markdown, JSON and `.uiproj`

It has no effect on UiPath. Studio and the Excel activities do not care. Do not re-normalise a
fetched template and do not add a `.gitattributes` to force LF **on these file types** — the
only cost is a noisy diff.

## Shell scripts are the exception

The repo *does* ship a `.gitattributes` with `*.sh text eol=lf`, and that is not a
contradiction of the paragraph above. A CRLF line ending inside a shebang —
`#!/usr/bin/env bash\r` — makes the script fail to execute on Linux, macOS, WSL and Git Bash,
because `bash\r` is not the name of any interpreter. Markdown and JSON tolerate CRLF; a shebang
does not.

So: `eol=lf` for `*.sh`, `binary` for `*.xlsx` and `*.nupkg`, and `text=auto` (i.e. leave it
alone) for everything else.
