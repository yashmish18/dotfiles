# Contributing

## Before submitting

- Run `./scripts/validate-package-manifests.sh`.
- Run `shellcheck install.sh uninstall.sh bin/* scripts/*.sh` when ShellCheck is available.
- Run `./install.sh --dry-run --yes` on Arch Linux.
- Test configuration changes in a clean VM profile.
- Do not commit personal data, credentials, machine-specific paths, or generated caches.

## Pull requests

Keep changes focused, explain hardware tested, and include a rollback or migration plan for installer or settings changes. Installer changes must preserve existing user files and report every system mutation.
