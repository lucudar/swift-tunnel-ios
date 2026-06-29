# Next Steps

1. Move this project to macOS.
2. Install XcodeGen.
3. Configure Apple bundle IDs, App Group, and Packet Tunnel entitlement.
4. Generate the Xcode project.
5. Build the app target and extension target.
6. Package unsigned IPA if signing happens outside Xcode.
7. Integrate the proxy core.

## Recommended Core Order

Start with one core, not three.

1. `sing-box` if GPLv3 is acceptable and feature coverage matters most.
2. `Xray-core` if VLESS/REALITY compatibility and MPL licensing matter more.
3. Custom adapter only after the first core is stable.

## MVP Scope

- Import one profile manually.
- Connect/disconnect.
- Debug logs.
- DNS protection.
- Basic full-tunnel mode.
- Real-device testing before adding auto-select and subscriptions.

