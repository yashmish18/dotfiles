# Contributing

## Before submitting

- Run `./scripts/validate-package-manifests.sh`.
- Run `shellcheck install.sh uninstall.sh bin/* scripts/*.sh` when ShellCheck is available.
- Run `./install.sh --dry-run --yes` on Arch Linux.
- Test configuration changes in a clean VM profile.
- Do not commit personal data, credentials, machine-specific paths, or generated caches.

## Pull requests

Keep changes focused, explain hardware tested, and include a rollback or migration plan for installer or settings changes. Installer changes must preserve existing user files and report every system mutation.

## Shell rules that prevent past bugs

- `running = true` on a `Process` that is still running does nothing. Either return early,
  re-check the input in `onExited` and run again, or create one process per request (`Media.run`).
- Before showing an async result, check it still matches what was asked for.
- Two change handlers must not depend on which fires first. Use one.
- State that must survive a shell restart goes on disk (see `Lock.qml`), not in the process
  or in environment variables.
- Package lists: one package per line (CI enforces it).
