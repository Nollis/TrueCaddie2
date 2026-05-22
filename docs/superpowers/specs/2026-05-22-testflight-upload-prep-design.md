# TestFlight Upload Prep Design

## Goal

Prepare the iOS host for a first TrueCaddie TestFlight pilot archive without
changing the voice architecture or turning this repo into a release pipeline.

## Scope

- Keep the current `PilotSecrets.swift` seam so the pilot archive can be made
  voice-enabled after the local `nil` value is replaced on the archive machine.
- Add a simple pilot app icon that Xcode can package for TestFlight and the
  installed app.
- Present the installed app as `TrueCaddie` rather than `TrueCaddieHost`.
- Make the host deployment target deliberate. Prefer a practical lower target
  when the host code compiles there; retain iOS 26.4 only if the code needs it.
- Add short TestFlight notes covering the manual checks that still matter:
  secret injection, version/build numbers, archive validation, and upload.

## Approach

This is a small release-readiness pass over the existing Xcode project. Asset
and metadata changes stay inside the host target. The credential path remains
local and explicit for the pilot rather than adding a new server or export
automation before the first upload path is proven.

## Verification

- Build or archive the host in Release mode for a generic iOS destination.
- Inspect the resulting archive metadata for app name, version, deployment
  target, icon payload, entitlements, and usage strings.
- Re-run the repo check path when project or Swift sources change.

## Out Of Scope

- Public App Store submission metadata, screenshots, and review materials.
- App Store Connect automation and exported IPA upload scripting.
- Hardened production realtime credential delivery.
