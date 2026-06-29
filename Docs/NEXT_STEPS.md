# Next Steps

1. Configure Apple bundle IDs, App Group, and Packet Tunnel entitlement.
2. Build the unsigned IPA from GitHub Actions.
3. Sign the IPA externally with matching Network Extension and App Group entitlements.
4. Test connect/disconnect on a real iPhone with one known-good VLESS, Trojan, or Shadowsocks profile.
5. Use the Debug tab to inspect Libbox startup and config validation errors.
6. Add latency testing and auto-select after real traffic is stable.

## Recommended Core Order

Start with one core, not three.

1. `sing-box` if GPLv3 is acceptable and feature coverage matters most.
2. `Xray-core` if VLESS/REALITY compatibility and MPL licensing matter more.
3. Custom adapter only after the first core is stable.

## sing-box Libbox

Upstream sing-box builds the Apple framework with:

```bash
go run ./cmd/internal/build_libbox -target apple -platform ios
```

That produces `Libbox.xcframework`, which is linked by the Packet Tunnel extension target. The app already generates sing-box JSON through `SingBoxConfigurationBuilder`.

This repository includes:

- `build-libbox-ios.yml` to test the framework build independently.
- `unsigned-ipa.yml` and `release-unsigned-ipa.yml` to build Libbox, generate the Xcode project, build the app, and package an unsigned IPA.

## MVP Scope

- Import one profile manually.
- Connect/disconnect.
- Debug logs.
- DNS protection.
- Basic full-tunnel mode.
- Real-device testing before adding auto-select and subscriptions.
