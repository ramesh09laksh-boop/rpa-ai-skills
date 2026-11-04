# `object-repository-not-shared`

A workflow binds to an Object Repository target by reference only; the descriptor itself lives
in `.objects/`. If that folder is missing, empty or git-ignored, the project's selectors do not
travel — a clone gets the workflows and resolves every target to nothing. Found in a real
project: 134 files under `.objects/`, none tracked.

| | |
|---|---|
| `bad` | a workflow references the Object Repository, `.objects/` holds no descriptors |
| `good` | the same workflow, with a descriptor present |

The git-ignored half of the rule is not covered here: the fixture is materialised outside a git
repository, so `git check-ignore` cannot be asked. Stated rather than left to be assumed.