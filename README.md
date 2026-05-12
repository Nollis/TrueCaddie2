# TrueCaddie

TrueCaddie is organized as a small monorepo while the course bundle contract is still evolving.

## Layout

- `course-studio/` prepares and publishes canonical course bundles.
- `ios/TrueCaddieDomain/` contains the Swift package for loading and validating course bundles.
- `ios/TrueCaddieHost/` contains the iOS host app that renders the current bundle inspector.
- `shared/` contains the bundle schema, pilot data snapshots, and published sample bundles.
- `openspec/` contains architecture and implementation proposals.

The first implementation slice is `course-bundle-foundation`: publish a canonical `kungsbacka-nya` pilot bundle and load it from the iOS-side domain contract.

## Verifying the bundle contract

Run the repo-level check to publish the pilot bundle, validate it against the shared JSON schema, and run the iOS domain tests:

```powershell
pwsh scripts/check.ps1   # Windows
```

```bash
scripts/check.sh         # macOS / Linux
```

The script skips the Swift step automatically if the `swift` CLI is not installed.
