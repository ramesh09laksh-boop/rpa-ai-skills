# `commands/` — the source of truth for the slash commands

Every file here is one slash command. **Edit these, never the generated copies.**

```bash
pwsh -NoProfile -File templates/tools/build-commands.ps1
```

That rewrites all three agents' formats from these files. The same rule as
`templates/tools/build-template-workbooks.ps1`: **edit the script and its source data, not the
output.** A hand-edit to a generated file is lost on the next run, and CI fails the PR that
contains one.

| Agent | Generated into | Format |
|---|---|---|
| Claude Code | `.claude/commands/<name>.md` | frontmatter `description`, `argument-hint` |
| GitHub Copilot | `.github/prompts/<name>.prompt.md` | frontmatter `description`, `argument-hint` |
| OpenCode | `.opencode/commands/<name>.md` | frontmatter `description` only — `argument-hint` is not an OpenCode field |

All three substitute `$ARGUMENTS`, which is why one body serves all three and the generator only
has to rewrite the frontmatter.

## Writing one

```markdown
---
description: One line. This is what shows in the `/` menu, so it is the only thing anyone reads.
argument-hint: "[what the argument is]"
---

Body. `$ARGUMENTS` is substituted with whatever the user typed after the command name.
```

`description` is required; `argument-hint` is optional. Nothing else is carried — a field the
generator does not know about is an error, not a silent drop.

## What belongs in a command, and what does not

A command is a **thin front door onto a skill**. It holds no stage logic, no gate and no estate
knowledge of its own.

- **Routing** — which skill to load, which stage to run. Yes.
- **Operating orders** — "carry the decision forward, do not re-ask", "continue to the next
  workflow without asking", "ask these four things in one message". Yes: these are instructions
  to the agent about *how to run*, which is not what a skill is for.
- **A gate, a stage number, a command's flags, a selector, a config key** — no. Those live in
  the skill, and `uc-delivery` wins when the two disagree. If a command starts restating what a
  skill says, delete the restatement and link to the skill.
- **Estate knowledge** — no. It goes into the owning skill or its `references/`, where every
  agent and every stage can reach it. `references/sdd-outline.md` in the `standards` skill got
  there this way, out of what used to be README's stage 1 prompt.

Stage numbering is `uc-delivery`'s: 1, 2, 3, 4–5, 6, 7, 7b, 8, 9, 10. Do not renumber it here.

## Getting them into a UC project

`npx skills add` installs **skills**, not commands — verified, see the CHANGELOG. So a UC
project gets them from the `project-scaffolding` skill's `fetch-commands` script, which is part
of its preflight/scaffold step.
