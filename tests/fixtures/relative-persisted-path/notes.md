# `relative-persisted-path`

At runtime the working directory is the EXTRACTED PACKAGE
(`%USERPROFILE%\.nuget\packages\<id>\<ver>\content\`), not the project folder. A relative output
path therefore writes into a directory that is discarded with the next published version. It
cost a whole audit trail on a real project.

| | |
|---|---|
| `bad` | `Data\Output\result.xlsx` |
| `good` | `C:\Data\UC99\Output\result.xlsx` |