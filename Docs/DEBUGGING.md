# Debugging

## First Launch

Check these in order:

1. App Group matches in `project.yml`, app entitlements, extension entitlements, and `AppConstants`.
2. Packet Tunnel entitlement exists for the app ID in Apple Developer portal.
3. `SwiftTunnelPacketTunnel.appex` is embedded in the app.
4. `AppConstants.tunnelBundleIdentifier` matches the extension bundle ID.
5. The Debug tab shows logs from both the app and extension.

## Expected MVP Behavior

The current tunnel uses `PlaceholderTunnelCore`. It validates the iOS VPN plumbing and logs startup, but it does not proxy traffic yet.

Expected result:

- iOS asks to add VPN configuration.
- Tapping connect starts the Packet Tunnel extension.
- Debug logs show `Starting packet tunnel`.
- Debug logs show placeholder core warning.

## Common Problems

- `permission denied`: missing Network Extension entitlement.
- `plugin failed`: extension bundle ID mismatch or extension not embedded.
- no shared logs: App Group mismatch.
- VPN starts but no traffic works: expected until real core adapter is integrated.
- signing fails: bundle IDs, App Group, or provisioning profiles do not match.

