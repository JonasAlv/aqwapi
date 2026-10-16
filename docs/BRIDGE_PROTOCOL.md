# External bridge protocol

The API includes `com.aqwapi.net.BridgeCommandRouter`, a transport-neutral request router intended to be called by an in-game Flash bridge after it receives a JSON request from the desktop host.

It does **not** open a socket or locate the AQW game root itself. The bridge host must initialize the API with the actual AQW root via `Api.init(gameRoot)`, then pass one JSON request line to `handleLine(line)` and return the resulting JSON response to the same client.

## Request envelope

The host accepts desktop requests over aqw-elec's WebSocket at `ws://127.0.0.1:4244`. In aqw-elec's documented architecture, the raw TCP endpoint is `127.0.0.1:4243` (not 4242). The exact adapter path from the WebSocket host to the Flash-side bridge must preserve the envelope below:

```json
{ "instanceId": 0, "id": 1, "type": "GetState" }
```

The Flash-side bridge must preserve `id` and `instanceId` when forwarding responses.

## Initial commands

| Command | Parameters | Result |
|---|---|---|
| `Ping` | none | Protocol version and API initialization state |
| `GetCapabilities` | none | List of commands implemented by this router |
| `GetState` | none | Readiness, player name/level/HP/MP/gold, alive/combat state, cell/pad and map |
| `JoinMap` | `map`, optional `cell`, `pad` | Accepted join request |
| `RunScript` | `script` containing HScript source | Loads and starts the HScript |
| `StopScript` | none | Requests script stop |
| `GetScriptStatus` | none | Current running flag and status text |

Successful response:

```json
{ "id": 1, "instanceId": 0, "success": true, "data": { "ready": true } }
```

Error response:

```json
{ "id": 1, "instanceId": 0, "success": false, "data": null, "error": "message" }
```

## Security and readiness

- Keep the bridge bound to loopback; do not expose it to the LAN or public internet.
- The initial protocol does not authenticate callers. Only run it on a trusted local machine and do not forward the port.
- `Ping.data.apiInitialized` reports whether the API has initialized; `GetState.data.ready` reports whether game/player state is available.
- A successful `JoinMap` response means the request was accepted by the API, not that the map transition completed.
- A successful `RunScript` response means the script was loaded and start was requested, not that every script operation succeeded.
- This router is a first integration seam. Runtime validation and the actual Flash socket/loader adapter are still required before the desktop UI can control the game.
