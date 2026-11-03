# `config-file-not-wired`

Stock Studio `Main.xaml` invokes `InitAllSettings` with the literal
`in_ConfigFile = "Data\Config.xlsx"`, and no template ships a `Config.xlsx` — they ship
`Config_TST.xlsx` and `Config_PRD.xlsx`. Left alone, the very first run dies in Initialization
with file-not-found. It is the single most likely break on a freshly instantiated template.

| | |
|---|---|
| `bad` | `Main.xaml` still passes `Data\Config.xlsx` |
| `good` | `Main.xaml` builds `Data\Config_<ENV>.xlsx` from `in_ENV` |