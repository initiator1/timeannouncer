# Publishing TimeAnnouncer

This is the final direct-download release path after local build and smoke checks pass.

## Owner Decisions

These items must be real before public distribution:

- Public support contact: replace the placeholder in `docs/support.md`.
- Public source or release host: configure the `origin` remote.
- Apple notarization: create the `timeannouncer-notary` keychain profile.

## One-Time Setup

Configure Apple notarization credentials:

```sh
xcrun notarytool store-credentials timeannouncer-notary
```

Configure a GitHub remote. For a public GitHub release, the remote repository must be reachable by public users:

```sh
git remote add origin <public-github-repository-url>
```

## Release Candidate

Build, notarize, staple, and verify the release artifact:

```sh
NOTARYTOOL_PROFILE=timeannouncer-notary ./scripts/build-release.sh
RUN_APP=1 ./scripts/smoke-release.sh
./scripts/launch-audit.sh
```

The audit must end with:

```text
Launch status: READY
```

## Publish

The publishing script uploads the DMG and its SHA-256 file to a GitHub release. It defaults to a draft release to prevent accidental public publishing.

Dry-run the publish command:

```sh
DRY_RUN=1 ./scripts/publish-github-release.sh
```

Create a draft GitHub release:

```sh
./scripts/publish-github-release.sh
```

Create the public latest release:

```sh
DRAFT_RELEASE=0 ./scripts/publish-github-release.sh
```

## Guardrails

- The script runs `scripts/launch-audit.sh` before publishing unless `SKIP_LAUNCH_AUDIT=1` is set.
- Release notes must not still be marked draft unless `ALLOW_DRAFT_NOTES=1` is set for a rehearsal.
- The script publishes only `TimeAnnouncer.dmg` and `TimeAnnouncer.dmg.sha256`; the zip remains a notarization/build artifact.
