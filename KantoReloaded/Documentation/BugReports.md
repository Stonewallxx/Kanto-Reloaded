# Kanto Reloaded Bug Reports

Kanto Reloaded provides a `File A Bug Report` action inside the About section
of KR settings.

## Workflow

The action:

1. Rebuilds `KantoReloaded/Logging/LatestBugReport.txt`.
2. Uploads the sanitized text report to `https://paste.rs/`.
3. Copies a Discord-ready `[Bug Report](url)` link when clipboard access is
   available.
4. Opens the bug-report Discord thread when URL opening is supported.

Windows and Proton expose the complete clipboard and browser workflow.
JoiPlay and unknown runtimes still create the local report and attempt the
upload; when desktop actions are unavailable, KR shows the uploaded URL or the
local report path instead.

The export runs behind a cancellable KR-styled progress popup. Cancelling the
upload does not delete the local report.

## Report Contents

Reports include KIF and KR versions, platform/runtime information, enabled mod
IDs and versions, KR registry counts, the current map and scene when available,
log severity totals, and the most recent KR log lines.

`Log.txt` rotates to `Log.previous.txt` at 2 MiB. Bug-report collection streams
both bounded files once to calculate severity totals and retain the newest 300
lines without loading the complete logs into memory.

Reports do not include save contents or player identity. KR removes absolute
game, user, and temporary paths and redacts authorization values, access and
refresh tokens, API keys, passwords, secrets, sensitive URL parameters, and
Discord webhook credentials before writing or uploading the report.

## APIs

```ruby
KantoReloaded::Log.export_bug_report
KantoReloaded::BugReport.file
```
