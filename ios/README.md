# TrueCaddie iOS

The iOS runtime consumes published course bundles and eventually runs the on-device strategy engine and voice flow.

The current repo contains:

- a domain package for loading and validating canonical bundles
- a hole-sketch layout module with unit tests
- a SwiftUI inspector view with a committed `#Preview` that loads the published `kungsbacka-nya` sample bundle

Swift tooling is not available in this local Windows environment, so simulator and preview verification still happen in an Apple toolchain on the Mac side.
