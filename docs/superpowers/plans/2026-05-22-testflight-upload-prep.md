# TestFlight Upload Prep Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Prepare the TrueCaddie iOS host for a first TestFlight pilot archive.

**Architecture:** Keep release prep inside the existing host target: project
metadata owns installed name and deployment target, the asset catalog owns the
pilot icon, and iOS docs own the manual archive checklist. Preserve the existing
local `PilotSecrets.swift` credential seam for this pilot.

**Tech Stack:** Xcode project settings, Swift host app, asset catalogs, Markdown
release notes, `xcodebuild`.

---

## File Map

- Modify `ios/TrueCaddieHost/TrueCaddieHost.xcodeproj/project.pbxproj` for
  TestFlight-facing metadata and any verified deployment-target change.
- Modify `ios/TrueCaddieHost/TrueCaddieHost/Assets.xcassets/AppIcon.appiconset`
  to add the pilot app icon image and register it in the asset catalog.
- Modify `ios/README.md` with the pilot archive checklist.
- Add host test coverage only if a Swift-facing release behavior changes.

### Task 1: Pilot Metadata

**Files:**
- Modify: `ios/TrueCaddieHost/TrueCaddieHost.xcodeproj/project.pbxproj`

- [ ] **Step 1: Probe the lower deployment target**

Run:

```bash
xcodebuild archive \
  -project ios/TrueCaddieHost/TrueCaddieHost.xcodeproj \
  -scheme TrueCaddieHost \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath /tmp/TrueCaddieHost-iOS17-Probe.xcarchive \
  IPHONEOS_DEPLOYMENT_TARGET=17.0 \
  -allowProvisioningUpdates
```

Expected: the archive either succeeds at iOS 17.0 or reports the API or build
setting that requires a higher target.

- [ ] **Step 2: Update installed metadata**

Set the host target display name to `TrueCaddie`. If the probe succeeds, lower
the project deployment target to `17.0`; otherwise keep the current target and
document the reason in the final report.

- [ ] **Step 3: Verify metadata in a fresh archive**

Run:

```bash
xcodebuild archive \
  -project ios/TrueCaddieHost/TrueCaddieHost.xcodeproj \
  -scheme TrueCaddieHost \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath /tmp/TrueCaddieHost-TestFlightPrep.xcarchive \
  -allowProvisioningUpdates
plutil -p /tmp/TrueCaddieHost-TestFlightPrep.xcarchive/Products/Applications/TrueCaddieHost.app/Info.plist
```

Expected: archive succeeds and `Info.plist` reports `TrueCaddie` display name
plus the chosen minimum OS.

### Task 2: Pilot Icon

**Files:**
- Create: `ios/TrueCaddieHost/TrueCaddieHost/Assets.xcassets/AppIcon.appiconset/TrueCaddiePilotIcon.png`
- Modify: `ios/TrueCaddieHost/TrueCaddieHost/Assets.xcassets/AppIcon.appiconset/Contents.json`

- [ ] **Step 1: Generate a simple icon bitmap**

Generate a square pilot icon with no text, no transparency, and golf/caddie
readability at small sizes. Save the selected 1024x1024 PNG into the app icon
asset set.

- [ ] **Step 2: Register the icon**

Add the PNG filename to the universal iOS 1024x1024 app icon entry in
`Contents.json`. Keep dark and tinted variants optional for this pilot.

- [ ] **Step 3: Verify archive icon packaging**

Run:

```bash
xcodebuild archive \
  -project ios/TrueCaddieHost/TrueCaddieHost.xcodeproj \
  -scheme TrueCaddieHost \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath /tmp/TrueCaddieHost-TestFlightPrep.xcarchive \
  -allowProvisioningUpdates
```

Expected: the archive succeeds and Xcode no longer archives an app with an
empty `AppIcon` asset set.

### Task 3: TestFlight Checklist

**Files:**
- Modify: `ios/README.md`

- [ ] **Step 1: Document the pilot archive sequence**

Add a concise TestFlight section that calls out:

```text
1. Replace `PilotSecrets.realtimeAPIKey = nil` locally before archiving a
   voice-enabled pilot build.
2. Confirm `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION`.
3. Archive the `TrueCaddieHost` scheme for a generic iOS destination.
4. Validate and upload from Xcode Organizer.
5. Restore the committed `nil` secret before pushing source changes.
```

- [ ] **Step 2: Run repo verification**

Run:

```bash
bash scripts/check.sh
git diff --check
```

Expected: repo checks pass and there are no patch whitespace errors.
