# Git Usage — second_engineer

## Commit message format

Use conventional commits:

```
type: short imperative summary (≤72 chars)

- bullet list of meaningful details
- one line per logical change

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
```

Valid types: `feat`, `fix`, `refactor`, `chore`, `docs`, `test`.

Pass the message with `-m "..."` directly — no heredoc or command substitution needed.

## What to stage

Stage only files directly related to the change. Always review `git status` before staging and explicitly name each file or directory — do not use `git add -A` or `git add .`.

**Never stage without checking first:**
- `mod-list.json` — records which mods are enabled in the local Factorio install; not part of mod source
- `mod-settings.dat` — binary; local Factorio settings
- `.env`, credentials, or any secrets

## What not to do

- Never use `--no-verify` (bypass hooks)
- Never force-push to `main`
- Never amend a published commit — create a new one instead
- Never use `git add -A` or `git add .`
