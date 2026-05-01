# CarlApp — Setup

## Prerequisites
- Xcode 15.3+ (iOS 17 SDK, Swift 5.10)
- macOS 14+
- [XcodeGen](https://github.com/yonoz/XcodeGen) (`brew install xcodegen`)

## Generate the Xcode project
```bash
xcodegen generate
open CarlApp.xcodeproj
```

`project.yml` is the source of truth for the project structure — never edit `CarlApp.xcodeproj` by hand. Add new files to the `CarlApp/` folders and re-run `xcodegen generate`.

## Run against fixtures (no hub needed)

The app boots with a `MockHubServer` (URLProtocol-based) that serves the JSON files in `CarlApp/Resources/Mocks/` for every endpoint defined in `api/openapi.yaml`. This is the default in Debug builds — you can develop the entire UI without a real hub.

Toggle in `CarlApp/App/CarlApp.swift`:
```swift
let useMockHub = true   // false = real hub via Bonjour discovery
```

## Run against a real hub
1. Flash a Carl hub running Phase 3+ firmware.
2. Hub exposes `_carl-hub._tcp` Bonjour service on the LAN.
3. Set `useMockHub = false` and run on a real device (Bonjour does not work in the iOS Simulator on a different network from the host).

## Cross-repo coordination
- `api/openapi.yaml` in this repo is the **iOS-side mirror** of the Carl hub HTTP contract. The authoritative copy lives in `Project-Carl/documents/api/openapi.yaml` once the Carl team adds it. Keep them in sync; the iOS team should open a Carl PR if changes are needed.
- `docs/qr-format.md` is the same: mirror of the Carl-side spec.
