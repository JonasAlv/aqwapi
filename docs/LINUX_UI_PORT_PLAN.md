# Linux Avalonia UI port plan

Status: planning baseline. Keep this work separate from the Haxe API implementation and never merge the parity branch into `main`.

## Repository boundaries

The UI should live in a **separate repository** from `aqw-haxe-api`. Suggested name: `aqw-linux-client`. The current GitHub integration can write files/branches in existing repositories but does not expose repository creation, so the empty UI repository must be created in GitHub before I can populate it directly.

The UI repository should contain the extracted/adapted Avalonia desktop application, host-side services, packaging, and Linux-specific integration. It should not vendor the Haxe API source or game assets.

The existing Haxe work remains in `feature/skua-parity-haxe`. `main` remains the clean baseline and must not receive these changes.

## Source and licensing boundary

- Use VibeSkua's Avalonia code as a reference and selectively port reusable UI code.
- Inspect VibeSkua's license before copying files; retain required notices and do not redistribute code/assets that the license does not permit.
- Keep proprietary game files out of Git. Load them from the configured official CDN at runtime.
- Avoid copying Windows-only Flash hosting, COM/ActiveX, WinForms, CoreHook, or Windows-specific injection code into the Linux application.

## Target architecture

1. **Avalonia UI**: account/session controls, script editor/console, settings, logs, status and diagnostics.
2. **Game-content gateway**: on every launch, serve the game's requested assets from the official CDN through a local HTTPS-aware reverse proxy, following the proven pattern in `aqw-elec`. Do not bundle a stale gamefiles snapshot. Respect upstream TLS validation, restrict upstream hosts/paths, and define caching/revalidation deliberately.
3. **Game host**: Linux-compatible host process behind an `IGameHost` abstraction. Keep the UI independent of the specific Flash runtime.
4. **Local API bridge**: loopback-only bridge with a versioned JSON request/response protocol, request IDs, explicit game-instance IDs, validation and a short-lived pairing token.
5. **Haxe API in the game runtime**: existing managers and script engine remain the authority for game state/actions. Preserve the current combat engine.
6. **CoreBots-style Haxe helpers**: high-level multi-step routines built on existing managers, exposed to scripts through the current HScript bindings.

## CDN loading on every launch

The default approach should match the user's stated goal and the existing `aqw-elec` reference: the launcher starts a local reverse proxy, and the client requests the main loader and dependent assets through it. The proxy fetches from the official CDN at request time, so current files are used rather than a bundled gamefiles directory.

Requirements:

- Resolve the current main loader/version using the official game's current version endpoint or the official loader URL; do not hardcode an old version.
- Restrict outbound requests to explicit official CDN hosts and expected paths. Normalize paths and reject traversal.
- Validate upstream TLS certificates. Do not copy `aqw-elec`'s `rejectUnauthorized: false` behavior.
- Forward required headers intentionally; avoid broad header spoofing and remove hop-by-hop headers.
- Choose an explicit cache policy. Default to revalidation/no stale game assets; allow caching only where correctness is preserved and upstream cache validators are honored.
- Handle upstream failure with a clear launch error. Do not silently serve corrupted or stale content.
- Keep account tokens and passwords out of URLs, logs, manifests, and bridge messages.
- Keep the reverse proxy bound to loopback. It is not a general-purpose open proxy.

If later measurements show that a particular asset should be cached locally, add a verified content cache with ETag/Last-Modified or SHA-256 validation. Do not download every asset blindly before launch when the client can fetch assets on demand.

## Linux and Flash runtime decision

Avalonia itself is cross-platform, but VibeSkua's current app project targets `net10.0-windows` and uses Windows-only Flash hosting code under `FlashUtil.cs`. It is not a drop-in Linux application.

Before porting the UI deeply, make a small runtime feasibility spike:

- determine which game-client host works on the target Linux distributions;
- confirm how the game SWF is loaded and how the Haxe API SWF is loaded into the same runtime;
- confirm the existing `aqw-elec` Pepper Flash approach works on the target machine;
- test a bridge round trip and graceful shutdown;
- document runtime and binary dependencies, including Pepper Flash's legacy/EOL status.

Do not assume Pepper Flash is a safe or maintainable final runtime. Isolate it behind `IGameHost` so it can be replaced later.

## Suggested UI repository layout

```text
AqwLinuxClient/
  src/
    AqwLinuxClient.App/          # Avalonia app, views and view models
    AqwLinuxClient.Core/         # host-independent UI/application services
    AqwLinuxClient.Content/      # CDN proxy and optional validated cache
    AqwLinuxClient.Bridge/       # versioned loopback JSON protocol client
    AqwLinuxClient.GameHost/     # host abstraction and Linux implementation
  tests/
    AqwLinuxClient.Content.Tests/
    AqwLinuxClient.Bridge.Tests/
  docs/
    ARCHITECTURE.md
    CDN_CONTENT.md
    BRIDGE_PROTOCOL.md
    LINUX_RUNTIME.md
```

Keep UI presentation separate from the CDN gateway and bridge. This allows both services to be tested without launching the game.

## Milestones

- [ ] Create an empty UI repository and confirm its default branch.
- [ ] Inventory VibeSkua Avalonia files and classify reusable UI versus Windows/game-host coupling.
- [ ] Create a minimal Avalonia Linux app that builds and starts.
- [ ] Implement the CDN reverse proxy with host/path restrictions and tests.
- [ ] Define and test the local bridge protocol independently of the UI.
- [ ] Run a game-host feasibility spike on Linux before choosing the permanent runtime.
- [ ] Connect the Haxe API to the bridge and test `Handshake`, `GetState`, one read-only query and one reversible action.
- [ ] Add script start/stop/logging and only then port more UI screens.
- [ ] Keep game files out of source control and never merge the API feature branch into `main`.

## First vertical slice

1. Launch UI.
2. Start the loopback CDN gateway and resolve the current game loader.
3. Start the game host.
4. Connect to the local API bridge and negotiate protocol version.
5. Query API/game readiness and player state.
6. Display connection status and logs.
7. Stop the script, client and gateway cleanly.

Do not port every VibeSkua screen before this slice works.
