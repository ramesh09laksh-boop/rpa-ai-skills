# `config-key-undefined`

A workflow reads a config key no sheet defines. The Dictionary returns `Nothing`, the
expression becomes `""`, and the run continues with an empty path, queue name or timeout. No
error, wrong behaviour.

| | |
|---|---|
| `bad` | reads `in_Config("Acme_System_Url")`, which no sheet defines |
| `good` | reads `in_Config("OrchestratorQueueName")`, which the base config defines |