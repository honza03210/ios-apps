# iOS apps monorepo → TestFlight

Several iOS apps, each in its own subdirectory under `apps/`, built and shipped
to **TestFlight** by a single GitHub Actions workflow. No developer Mac is
required — signing is fully automatic via an App Store Connect API key, and
builds install over the air through the TestFlight app.

## Layout

```
.
├── apps/
│   ├── HelloTestFlight/             # example app — title + tap counter
│   │   ├── project.yml              # XcodeGen config (name: HelloTestFlight)
│   │   └── HelloTestFlight/         # sources
│   │       ├── HelloTestFlightApp.swift
│   │       ├── ContentView.swift
│   │       ├── Info.plist
│   │       ├── HelloTestFlight.entitlements
│   │       └── Assets.xcassets/     # incl. 1024px AppIcon
│   └── ColorRoll/                   # second app — tap to cycle background color
│       ├── project.yml              # name: ColorRoll
│       └── ColorRoll/ …             # same shape as above
└── .github/workflows/
    └── testflight.yml
```

The `.xcodeproj` is **not** committed — XcodeGen regenerates it in CI.

## Conventions (keep them and adding an app needs zero workflow edits)

- One app per `apps/<Name>/`, each containing a `project.yml`.
- In each `project.yml`, the project `name:`, the app target, and the scheme are
  all `<Name>` (matching the directory). The workflow builds
  `-project <Name>.xcodeproj -scheme <Name>`.
- Each app has a **unique bundle id** and its own App Store Connect app record.

## One-time setup

1. **Apple Developer Program** membership ($99/yr).
2. For **each app**: App Store Connect → Apps → **+** → create a record with the
   app's bundle id (e.g. `com.example.hellotestflight` for the sample). With
   automatic signing the App ID is auto-created on first archive.
3. Create **one App Store Connect API key** (team-wide): Users and Access →
   Integrations → **App Store Connect API** → generate a key with **App Manager**
   access. Download the `.p8` once; record the **Key ID** and **Issuer ID**.
4. Note your **Team ID** (10 chars, Membership page).

### Repository secrets

Settings → Secrets and variables → Actions:

| Secret | Value |
|---|---|
| `ASC_KEY_ID` | App Store Connect API key id |
| `ASC_ISSUER_ID` | issuer id (UUID) |
| `ASC_KEY_P8` | full contents of the `AuthKey_<id>.p8` file, pasted as-is |
| `APPLE_TEAM_ID` | 10-char team id |

## Running it

- **Push** to `main` touching `apps/**` → only the **changed** apps build & upload.
- **Actions → TestFlight → Run workflow** → build **all** apps, or type one app's
  subdir name to target just that one.

## Installing the result

Add yourself as an **internal tester** in App Store Connect → your app →
TestFlight (no App Review needed). Install via the **TestFlight** app on device,
over the air.

## Unsigned builds for AltStore / SideStore

Don't want to deal with App Store Connect at all? The **Unsigned IPA (AltStore)**
workflow (`.github/workflows/unsigned.yml`) builds each app with code signing
disabled and uploads the resulting **unsigned `.ipa`** as a workflow artifact —
**no secrets, no Apple Developer Program, no app records needed**. AltStore (or
SideStore) re-signs the IPA on-device with your own free Apple ID at install time.

1. **Actions → Unsigned IPA (AltStore) → Run workflow.** Leave `app` as `all`,
   or type one app's subdir name.
2. When it finishes, open the run and download the **`<App>-unsigned-ipa`**
   artifact (a zip containing the `.ipa`); unzip it.
3. Install the `.ipa` with AltStore/SideStore (AltServer "Install app…", or drag
   it into SideStore). It gets re-signed with a free provisioning profile.

Caveats of the free-Apple-ID route (AltStore's, not this repo's): the app expires
after **7 days** (AltStore refreshes it in the background), you're limited to
**3 sideloaded apps** at once, and capabilities that require a paid account
(e.g. some entitlements) won't work. For anything beyond casual sideloading, use
the TestFlight workflow above.

## Adding a new app

1. Create `apps/<Name>/project.yml` (project + target + scheme all named `<Name>`)
   plus sources / `Info.plist` / entitlements / `Assets.xcassets` (with an
   AppIcon).
2. Create the app record in App Store Connect with its bundle id.
3. Push. The `discover` job finds it; the matrix builds and uploads it.

## The example apps

- **`HelloTestFlight`** (`com.example.hellotestflight`) — a one-screen SwiftUI
  app with a title, subtitle, and a tap counter.
- **`ColorRoll`** (`com.example.colorroll`) — tap anywhere to cycle the
  background color.
- **`Showcase`** (`com.example.showcase`) — a tour of iOS hardware & ML
  capabilities, one screen each: TrueDepth face blendshapes, on-device speech
  recognition, Vision hand/body pose, image classification, OCR, sound
  classification, device-motion/barometer/pedometer, Core Haptics, Natural
  Language, Bluetooth LE scan, Nearby Interaction (UWB) capabilities, NFC, and
  Face ID. Needs a real device for most demos.

Both build with no special capabilities, so together they're the simplest proof
that the discover → archive → upload pipeline works end to end **and** that the
matrix fans out across multiple apps: a push that changes both directories runs
two macOS jobs in parallel, one per app. Each needs its own App Store Connect
app record (matching its bundle id) before its upload will succeed.

See `docs/ios-monorepo-testflight.md` (in the in-zone repo) for the full
blueprint and the hard-won gotchas behind this setup.
