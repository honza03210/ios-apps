# iOS apps monorepo → TestFlight

Several iOS apps, each in its own subdirectory under `apps/`, built and shipped
to **TestFlight** by a single GitHub Actions workflow. No developer Mac is
required — signing is fully automatic via an App Store Connect API key, and
builds install over the air through the TestFlight app.

## Layout

```
.
├── apps/
│   └── HelloTestFlight/             # example app (proves the pipeline)
│       ├── project.yml              # XcodeGen config (name: HelloTestFlight)
│       └── HelloTestFlight/         # sources
│           ├── HelloTestFlightApp.swift
│           ├── ContentView.swift
│           ├── Info.plist
│           ├── HelloTestFlight.entitlements
│           └── Assets.xcassets/     # incl. 1024px AppIcon
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

## Adding a new app

1. Create `apps/<Name>/project.yml` (project + target + scheme all named `<Name>`)
   plus sources / `Info.plist` / entitlements / `Assets.xcassets` (with an
   AppIcon).
2. Create the app record in App Store Connect with its bundle id.
3. Push. The `discover` job finds it; the matrix builds and uploads it.

## The example app

`HelloTestFlight` is a one-screen SwiftUI app (a title, subtitle, and a tap
counter). It builds with no special capabilities, so it's the simplest possible
proof that the discover → archive → upload pipeline works end to end. Once the
secrets above are set and an app record exists for `com.example.hellotestflight`,
pushing this repo uploads a build to TestFlight.

See `docs/ios-monorepo-testflight.md` (in the in-zone repo) for the full
blueprint and the hard-won gotchas behind this setup.
