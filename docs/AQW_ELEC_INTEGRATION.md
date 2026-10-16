# aqw-elec integration findings

This is a source-based note to guide the Linux UI port. `aqw-elec` is a reference for hosting and transport, not the project to port wholesale.

## What the source currently does

Source: [`src/main/main.ts`](https://github.com/JonasAlv/aqw-elec/blob/main/src/main/main.ts), plus its README.

- Starts a local HTTP reverse proxy on `127.0.0.1:8080`.
- Proxies game asset requests to `https://game.aq.com/game...` and handles selected root-level paths separately.
- Uses a current loader route and forwards dependent assets on demand; this avoids bundling a stale full gamefiles snapshot.
- Serves optional `assets/bridge.swf`; if absent, it redirects the loader request to the official `Loader3.swf`.
- Starts a Flash-to-host TCP server on `127.0.0.1:4242` for the SWF bridge.
- Starts an external API TCP server on `127.0.0.1:4243` and WebSocket server on `127.0.0.1:4244`.
- Routes JSON messages by `instanceId`, maps request IDs to requesting API clients, and sends responses back to the caller. Events without request IDs are broadcast.
- Exposes host-level commands such as screenshot and tab operations separately from game commands.

The API examples in the README include `GetState` and `JoinMap`, but those commands are handled by `bridge.swf`; the Electron host primarily routes messages. Do not assume the Haxe API's entire public surface is already callable through that bridge.

## What we should reuse conceptually

- **Live CDN reverse proxy:** fetch the loader and dependent files from the official CDN during each launch/session rather than committing game assets.
- **Transport separation:** one host-side port for the Flash bridge and a separate external API endpoint.
- **Request correlation:** request IDs and per-instance routing prevent one account's response being delivered to another.
- **Explicit lifecycle events:** instance connected/disconnected notifications let the UI reflect the actual game-host state.
- **Small initial command allowlist:** start with handshake, readiness/state, diagnostics, inventory summary, script start/stop, and one reversible action.

## What should not be copied blindly

- The host currently disables TLS certificate validation for proxied upstream requests. The Linux port should retain certificate validation.
- It uses legacy Electron 11 and Pepper Flash. Keep this as a feasibility/reference path, not a permanent runtime commitment.
- Binding to loopback reduces exposure but is not authentication. Add a short-lived pairing token or another host-local authorization mechanism for the new protocol.
- Do not copy hardcoded developer machine paths.
- Avoid arbitrary reflection or a generic “call any function” bridge. Expose explicit, validated commands.
- Keep the bridge separate from `TransportAdapter`: the latter listens for AQW extension responses inside the game runtime and dispatches HScript events; it is not itself the desktop API server.

## First live bridge test

1. Host starts and reports its bridge endpoints.
2. Game-side SWF bridge connects and receives an assigned instance ID.
3. UI sends `Handshake` with protocol version.
4. UI sends `GetState`; response includes game-ready and Haxe-API-ready flags.
5. UI sends a small read-only inventory query.
6. Only after those pass, test a reversible map join and then script start/stop.

Log correlation ID, instance ID, command name, duration and error code. Never log credentials or tokens.
