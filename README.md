# SwiftTunnel

Minimal iOS VPN/proxy client focused on clean code, debug-first behavior, a black/white SwiftUI interface, and a sing-box engine through `Libbox`.

## Current Features

- SwiftUI app shell with dark/light minimal UI.
- `NETunnelProviderManager` setup for a Packet Tunnel extension.
- Shared app group config store.
- JSONL debug logger shared between app and extension.
- Packet tunnel skeleton with DNS protection, basic route settings, MTU, and explicit core integration point.
- sing-box JSON generation for VLESS, Trojan, and Shadowsocks profiles.
- `LibboxTunnelCore` integration for the Packet Tunnel extension when `Libbox.xcframework` is available.
- iOS platform adapter for TUN settings, DNS hijack, default-interface monitoring, and tunnel file descriptor handoff.
- Import UI for `vless://`, `trojan://`, and `ss://` links.
- XcodeGen project definition.

## Requirements

- macOS with Xcode.
- XcodeGen.
- Apple Developer account with Network Extension capability.
- App Group and Packet Tunnel entitlements enabled for your bundle IDs.

## Generate Project

```bash
cd ios-vpn-client
# Build or download Libbox.xcframework into Frameworks/Libbox.xcframework first.
xcodegen generate
open SwiftTunnel.xcodeproj
```

Before building, edit `project.yml`:

- `DEVELOPMENT_TEAM`
- `PRODUCT_BUNDLE_IDENTIFIER`
- `AppConstants.appGroupIdentifier`
- `AppConstants.tunnelBundleIdentifier`
- app group values in both entitlements files

All identifiers must match your Apple Developer portal setup.

If your XcodeGen version does not embed the extension automatically, open the generated project and check:

```text
SwiftTunnel target -> General -> Frameworks, Libraries, and Embedded Content
```

`SwiftTunnelPacketTunnel.appex` must be embedded.

## Build Unsigned App For External Signing

On macOS:

```bash
xcodebuild build \
  -project SwiftTunnel.xcodeproj \
  -scheme SwiftTunnel \
  -configuration Release \
  -destination "generic/platform=iOS" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="" \
  -derivedDataPath build/DerivedData
```

Then find the generated `.app` under:

```text
build/DerivedData/Build/Products/Release-iphoneos/
```

Package it with the local Codex skill script:

```bash
python ~/.codex/skills/ios-ipa-builder/scripts/package_unsigned_ipa.py \
  --app build/DerivedData/Build/Products/Release-iphoneos/SwiftTunnel.app \
  --output build/SwiftTunnel-unsigned.ipa \
  --overwrite
```

The result is an unsigned IPA container. Final signing remains your external/on-device step.

## GitHub Releases

The repo includes two workflows:

- `unsigned-ipa`: builds an unsigned IPA and uploads it as a workflow artifact.
- `release-unsigned-ipa`: builds an unsigned IPA and publishes it to GitHub Releases.

Both workflows build `Libbox.xcframework` from `SagerNet/sing-box@v1.13.14` before generating the Xcode project. The framework is not committed because it is large.

Run `release-unsigned-ipa` manually from the Actions tab and provide a tag such as:

```text
v0.1.1-unsigned
```

## Core Integration

The main integration points are:

```text
PacketTunnel/Sources/PacketTunnel/PacketTunnelProvider.swift
PacketTunnel/Sources/PacketTunnel/LibboxTunnelCore.swift
PacketTunnel/Sources/PacketTunnel/LibboxPlatformAdapter.swift
```

The app UI stays independent from the core. The UI edits `TunnelConfiguration`; the extension generates sing-box config, starts Libbox, applies TUN settings, forwards logs to `DebugLogger`, and stops the core in `stopTunnel`.
