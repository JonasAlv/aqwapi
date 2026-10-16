# HScript timed handlers

This branch adds a cooperative timed-handler registry based on Skua's `IScriptHandlers` contract.

## Available API

Both a global namespace and the API namespace resolve to the registry:

```haxe
// Register a recurring handler. Return true (or any value other than false) to keep it.
handlers.registerHandler(5, function(bot) {
    log("periodic check");
    return true;
}, "periodic-check");

// Register a one-shot callback.
Bot.Handlers.RegisterOnce(10, function(bot) {
    log("runs once");
}, "delayed-once");

// Remove by name or clear all handlers.
handlers.remove("periodic-check");
handlers.clear();
```

Skua-style PascalCase aliases are provided for `RegisterHandler`, `RegisterOnce`, `Remove`, `Clear`, and `CurrentHandlers`. Lower-camel Haxe names are also available.

## Runtime behavior

- One Skua tick is 20 ms; the HScript engine currently wakes every 100 ms by default. The handler manager measures requested intervals in 20 ms units but executes on the next HScript host tick, so it cannot run more frequently than the host timer.
- Handlers are ticked while an HScript is running and while its `sleep()` wait timer is active.
- A callback receives the `Api` class object as its first argument; inside the HScript environment, use the existing Haxe API naming conventions (e.g. `bot.map`, `bot.player`). This is not a complete case-compatible implementation of Skua's C# `IScriptInterface`.
- A callback returning exactly `false` is removed. `registerOnce` always removes after invocation. A thrown callback is logged and removed so it cannot repeatedly break the tick loop.
- Handler state is cleared at script start and after the script's `onStop` callback to avoid stale closures leaking into later scripts.
- `CurrentHandlers` returns a copy of the current list.

## Validation still required

This repository could not be cloned in the current environment, and no Haxe compiler is installed here, so these changes have not been compiled or run in a Flash runtime. Before treating the feature as complete, verify:
1. Haxe SWC build accepts the new files/properties.
2. `handlers.registerHandler` and `Bot.Handlers.RegisterHandler` resolve through HScript.
3. A handler returning false is removed; one returning true continues; `RegisterOnce` fires once.
4. A handler continues during `sleep()` and stops after script shutdown.
5. A script exception or map transition does not leave stale callbacks registered.
