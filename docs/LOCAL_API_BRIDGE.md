# Local game/API bridge protocol (proposal)

Status: design proposal, not yet implemented. This document defines a minimal testable boundary between a Linux desktop UI and the Haxe API running in the AQW client.

## Design constraints

- Haxe remains the implementation language for in-runtime game operations.
- Existing `aqw-haxe-api` managers are the source of truth.
- Preserve the current Haxe combat system; the bridge calls its public methods rather than reimplementing combat.
- Keep transport distinct from game operations: an exposed manager method is not remotely callable until a bridge handler maps it.
- Bind to loopback only. Never expose an unauthenticated game-control socket to a LAN interface.
- Treat commands as untrusted input: validate command names, types, argument lengths, payload sizes and rate limits.
- Include a protocol version and explicit instance/session ID in every message.
- Return structured errors and correlation IDs. Do not silently swallow command failures.

## Transport choice

The UI and local host should communicate over loopback WebSocket because it is easy to use from Avalonia/.NET and supports request/response plus event streams. A small host-side broker may be required if the selected Flash runtime cannot originate WebSocket connections.

Do not assume a Haxe SWF can speak WebSocket directly. Flash runtimes historically provide different socket APIs and sandbox rules. Confirm the exact bridge path in a runtime spike before implementing the Haxe transport adapter. The existing `aqw-elec` bridge is a reference implementation, not a requirement to keep Electron as the permanent UI.

The bridge should have a generated, unpredictable session token for each host launch. The host passes it to the game-side bridge through a trusted launch/configuration path; reject all connections without it. If the Flash sandbox makes a secure token handoff impractical, document the threat model and use a narrow local-only broker with a short-lived pairing handshake.

## Envelope

Requests:

```json
{
  "protocol": 1,
  "instanceId": "session-1",
  "requestId": "req-0001",
  "type": "request",
  "command": "GetState",
  "args": {}
}
```

Successful response:

```json
{
  "protocol": 1,
  "instanceId": "session-1",
  "requestId": "req-0001",
  "type": "response",
  "ok": true,
  "result": {
    "ready": true
  }
}
```

Error response:

```json
{
  "protocol": 1,
  "instanceId": "session-1",
  "requestId": "req-0001",
  "type": "response",
  "ok": false,
  "error": {
    "code": "NOT_READY",
    "message": "Game state is not available yet"
  }
}
```

Unsolicited event:

```json
{
  "protocol": 1,
  "instanceId": "session-1",
  "type": "event",
  "event": "GameReady",
  "data": {}
}
```

## Initial command allowlist

Start with a small, explicit command set:

| Command | Purpose | Safety |
|---|---|---|
| `Handshake` | Negotiate protocol version and capabilities | Read-only |
| `GetState` | API/bridge readiness and player/map summary | Read-only |
| `GetDiagnostics` | Bridge status, API version, current script status | Read-only |
| `GetInventorySummary` | Small inventory summary needed to prove API queries | Read-only |
| `JoinMap` | Exercise one reversible game action | Mutating; validate map/cell/pad |
| `StartScript` | Start a named Haxe script already available in the API | Mutating; explicit confirmation in UI |
| `StopScript` | Stop current script and run cleanup | Mutating; always available |

Do not expose arbitrary Haxe reflection or arbitrary function execution as the initial protocol. Add individual commands after validation and tests. Do not put account passwords, authentication cookies, or session credentials in bridge messages or logs.

## Error codes

At minimum: `BAD_REQUEST`, `UNSUPPORTED_PROTOCOL`, `UNAUTHORIZED`, `UNKNOWN_COMMAND`, `NOT_READY`, `TIMEOUT`, `CANCELLED`, `EXECUTION_FAILED`, `RATE_LIMITED`.

## Readiness and lifecycle

- Bridge connected does not imply game ready.
- Game ready does not imply the Haxe API has initialized.
- API ready does not imply a script is running.
- Emit explicit readiness transitions and include current state in `GetState`.
- On disconnect, mark the UI as disconnected and stop issuing new actions. Do not automatically repeat mutating commands unless they have an idempotency key.
- On host shutdown, stop scripts, close sockets, remove temporary pairing material and flush logs.

## Test plan

1. Unit-test JSON validation, protocol version checks, command allowlist and error envelopes.
2. Test unauthorized connection rejection and loopback binding.
3. Test duplicate request IDs and timeout behavior.
4. Test `Handshake` and `GetState` with a fake API endpoint.
5. In the actual client, test handshake, state read, inventory read, then `JoinMap`.
6. Verify the existing combat engine is unchanged and remains callable from scripts after bridge integration.

## Implementation note

The existing Haxe `TransportAdapter` listens for AQW game extension responses (`onExtensionResponse`) and dispatches game events to HScript. That is an in-game event/packet adapter, not by itself a desktop UI bridge. Keep it intact and add a separate bridge adapter at the host/runtime boundary once the actual SWF communication mechanism is confirmed.
