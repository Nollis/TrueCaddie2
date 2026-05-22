# TrueCaddie iOS

The iOS runtime consumes published course bundles and eventually runs the on-device strategy engine and voice flow.

The current repo contains:

- `TrueCaddieHost/`, the iOS app shell used to run the current inspector UI
- a domain package for loading and validating canonical bundles
- a hole-sketch layout module with unit tests
- a SwiftUI inspector feature with a committed `#Preview` that loads the bundled `kungsbacka-nya` sample bundle

Open `TrueCaddieHost/TrueCaddieHost.xcodeproj` to run the app. The app root loads the bundled `kungsbacka-nya.v1.json` sample and displays `BundleInspectorView`.

## TestFlight Pilot

Before archiving a voice-enabled pilot build:

1. Replace `PilotSecrets.realtimeAPIKey = nil` locally in
   `TrueCaddieHost/TrueCaddieHost/App/PilotSecrets.swift`.
2. Confirm `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` in the
   `TrueCaddieHost` target. App Store Connect treats the build number as the
   unique build string for each upload.
3. Archive the `TrueCaddieHost` scheme for a generic iOS destination.
4. Validate and upload the archive from Xcode Organizer to TestFlight.
5. Restore the committed `nil` secret before pushing source changes.

The pilot source keeps the realtime credential seam local on purpose. Do not
commit a real key.
