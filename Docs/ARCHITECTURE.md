# Architecture

```text
SwiftTunnel app
  -> SwiftUI screens
  -> VPNManager
  -> TunnelConfigurationStore
  -> NETunnelProviderManager

PacketTunnel extension
  -> PacketTunnelProvider
  -> TunnelConfigurationStore
  -> SingBoxConfigurationBuilder
  -> TunnelCore adapter
  -> proxy core
  -> NEPacketTunnelFlow
```

## Rules

- Keep app and extension state in the App Group container.
- Keep private keys, tokens, and subscription secrets out of logs.
- Keep UI code away from core networking details.
- Keep Packet Tunnel startup deterministic: validate config, apply network settings, start core, log each phase.
- Prefer one small adapter per proxy core rather than mixing core-specific code into the provider.
- Generate proxy-core config from `TunnelConfiguration` before starting the tunnel.
- Keep generated config previewable from Debug so bad profile imports are visible before core startup.

## Performance Priorities

- Prefer Hysteria2/TUIC on unstable mobile networks.
- Prefer VLESS + REALITY/TLS/Vision for stable TCP paths.
- Keep rule sets compact on iOS to reduce extension memory pressure.
- Use MTU `1280` first, then tune after real device tests.
- Avoid verbose logging in release builds.

## sing-box Status

The app now generates sing-box JSON for:

- TUN inbound
- DNS protection
- route mode
- VLESS outbound
- Trojan outbound
- Shadowsocks outbound

The current tunnel still uses `PlaceholderTunnelCore`. Replace it with a Libbox adapter after adding `Libbox.xcframework` to the Xcode project.

## Debug Priorities

- Log startup phase boundaries.
- Convert core errors into user-readable messages.
- Preserve enough raw error detail for diagnostics.
- Never log UUIDs, passwords, private keys, or full subscription URLs.
