# Debugging

## First Launch

Check these in order:

1. App Group matches in `project.yml`, app entitlements, extension entitlements, and `AppConstants`.
2. Packet Tunnel entitlement exists for the app ID in Apple Developer portal.
3. `SwiftTunnelPacketTunnel.appex` is embedded in the app.
4. `AppConstants.tunnelBundleIdentifier` matches the extension bundle ID.
5. The Debug tab shows logs from both the app and extension.

## Expected Engine Behavior

When `Libbox.xcframework` is present in `Frameworks/`, the Packet Tunnel extension starts sing-box through `LibboxTunnelCore`.

Expected result:

- iOS asks to add VPN configuration.
- Tapping connect starts the Packet Tunnel extension.
- Debug logs show `Starting packet tunnel`.
- Debug logs show `Started sing-box ...`.
- Traffic is routed through the active VLESS, Trojan, or Shadowsocks profile.

If `Libbox.xcframework` is missing in a local build, the extension uses `PlaceholderTunnelCore`. That fallback only validates VPN plumbing and does not proxy traffic.

## Common Problems

- `permission denied`: missing Network Extension entitlement.
- `plugin failed`: extension bundle ID mismatch or extension not embedded.
- no shared logs: App Group mismatch.
- VPN starts but no traffic works: check that `Libbox.xcframework` exists before `xcodegen generate`, then check the Debug tab for `Libbox` startup or config validation errors.
- signing fails: bundle IDs, App Group, or provisioning profiles do not match.
