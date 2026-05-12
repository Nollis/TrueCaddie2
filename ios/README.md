# TrueCaddie iOS

The iOS runtime consumes published course bundles and eventually runs the on-device strategy engine and voice flow.

The current repo contains:

- `TrueCaddieHost/`, the iOS app shell used to run the current inspector UI
- a domain package for loading and validating canonical bundles
- a hole-sketch layout module with unit tests
- a SwiftUI inspector feature with a committed `#Preview` that loads the bundled `kungsbacka-nya` sample bundle

Open `TrueCaddieHost/TrueCaddieHost.xcodeproj` to run the app. The app root loads the bundled `kungsbacka-nya.v1.json` sample and displays `BundleInspectorView`.
