# Next Steps

1. Move this project to macOS.
2. Install XcodeGen.
3. Configure Apple bundle IDs, App Group, and Packet Tunnel entitlement.
4. Generate the Xcode project.
5. Build the app target and extension target.
6. Package unsigned IPA if signing happens outside Xcode.
7. Add `Libbox.xcframework` or another proxy core framework.
8. Replace `PlaceholderTunnelCore` with the real core adapter.

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

That produces `Libbox.xcframework`, which should be added to both the app and Packet Tunnel extension targets. The app already generates sing-box JSON through `SingBoxConfigurationBuilder`.

This repository includes `build-libbox-ios.yml` to test that framework build independently before wiring it into the app.

## MVP Scope

- Import one profile manually.
- Connect/disconnect.
- Debug logs.
- DNS protection.
- Basic full-tunnel mode.
- Real-device testing before adding auto-select and subscriptions.
