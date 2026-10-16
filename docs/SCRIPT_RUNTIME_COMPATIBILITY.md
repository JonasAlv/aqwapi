# HScript runtime compatibility notes for Skua script ports

The Haxe API currently runs HScript through a timer-driven `onStart` / `onTick` / `onStop` model. This is not the same execution model as Skua's C# scripts, which can use ordinary sequential control flow, blocking-looking wait helpers, tasks, and cancellation tokens.

## Existing HScript lifecycle

- Script source is parsed and top-level code is executed by `HScriptEngine.loadScript`.
- `onStart()` is called once when started.
- `onTick()` is called on each timer tick (100ms by default).
- Optional `onStop()`, `onPacket(type, cmd, data)`, `onZoneEntered(data)`, `onQuestUpdated(data)`, and `onInventoryChanged(data)` callbacks are supported.
- `sleep(ms)` sets `waitTimer`, which skips later `onTick` calls until the timer expires. It does **not** suspend the current call stack or prevent later statements in the same `onTick` from executing.
- The new timed handlers are invoked by the host tick even while `sleep()` is active.

## Implication for Skua compatibility

A direct textual port of a synchronous Skua script is not safe if it assumes that `Sleep` or `Wait.ForTrue` pauses the current function and resumes it later. HScript cannot simply suspend and restore the current stack at an arbitrary function call. Blocking the Flash/UI thread would also stop the client from processing the events that the wait depends on.

For this API, multi-step workflows must be cooperative:
- Call a helper repeatedly from `onTick`.
- Each call inspects current game state, performs at most the next safe action, and returns whether the goal is complete.
- Preserve progress in a small workflow state object when a helper spans multiple steps.
- Include bounded timeout, cancellation, and failure reason in new workflow helpers.
- Keep low-level manager operations asynchronous/queued where they already are.

Example:

```haxe
var farmDone = false;

function onStart() {
    farmDone = false;
}

function onTick() {
    if (farmDone) return;

    if (CoreBots.EnsureMap("battleon", "Enter", "Spawn")) {
        farmDone = CoreBots.FarmItem("Training Golem", "Sample Item", 1);
    }
}
```

The example illustrates the cooperative shape only; the exact meaning of the current `FarmItem` return value is inherited from `CombatManager.farmItem` and still needs method-level validation.

## Migration rule

- Low-level synchronous property reads and immediate commands can usually be mapped directly.
- Skua wait/task methods require a cooperative equivalent or a script rewrite.
- CoreBots-style multi-step methods should own their progress, prerequisites, timeouts, cancellation and cleanup, so individual scripts do not each reinvent the same state machine.
- Do not change `sleep()` to throw or block as a shortcut: either behavior can break existing scripts or freeze the Flash client.
