# CoreBots-style HScript facade

Branch: `skua-haxe`

## What is implemented

`src/com/aqwapi/scripting/CoreBots.hx` introduces the `CoreBots` / `core` namespace in HScript. It delegates to the existing `ScriptBindings` shortcuts rather than duplicating the logic or replacing the existing combat engine.

Examples:

```haxe
// Namespaced equivalents of existing HScript helpers:
CoreBots.ensureMap("battleon", "Enter", "Spawn");
CoreBots.EnsureItems(["Required Item", 12345]);
CoreBots.storyChainQuest(1234, "battleon");
CoreBots.farmItem("Training Golem", "Sample Item", 1);

// The lowercase alias is also available:
core.ensureRestored();
core.ensureQuestsLoaded([1234, 5678]);
```

Current facade methods:

- `ensureItems(items, quantity, moveToInventory)` / `EnsureItems(...)`
- `ensureAnyItem(items, quantity, moveToInventory)` / `EnsureAnyItem(...)`
- `checkItem(item, quantity, moveToInventory)` / `CheckItem(...)`
- `checkInventory(items, quantity, any, toInv)` / `CheckInventory(...)`
- `ensureAccept(questId)` / `EnsureAccept(...)`
- `ensureComplete(questId, itemId)` / `EnsureComplete(...)`
- `ensureLoad(questId)` / `EnsureLoad(...)`
- `getMapItem(itemId, quantity, mapName)` / `GetMapItem(...)`
- `join(mapName, cell, pad, publicRoom, ignoreCheck)` / `Join(...)`
- `joinMap(mapName, cell, pad)` / `JoinMap(...)`
- `jump(cell, pad, ignoreCheck)` / `Jump(...)`
- `killMonster(map, cell, pad, monster, item, quantity, isTemp)` / `KillMonster(...)`
- `huntMonster(map, monster, item, quantity, isTemp)` / `HuntMonster(...)`
- `huntMonsterQuest(questId, monsterName)` / `HuntMonsterQuest(...)`
- `ensureMap(mapName, cell, pad)`
- `quest(questId, mapName)`
- `storyChainQuest(questId, mapName)`
- `mapItem(itemId, arg2, arg3, arg4)`
- `farmItem(monster, item, quantity, isTemp)`
- `huntItem(monster, item, quantity, mapName)`
- `complete(questId, rewardChoice)`
- `ensureEquipped(itemName)`
- `ensureRestored()`
- `hasItem(itemName, quantity)`
- `ensureQuestsLoaded(questIds)`
- `stopCombat()`
- `stopAutoQuest()`

## Behavioral contract and limitations

- This is an **initial facade**, not a complete port of external Skua CoreBots script libraries.
- Existing shortcut semantics are preserved. For multi-tick helpers, scripts must continue calling the helper on successive HScript ticks until it reports completion, according to the underlying helper's existing contract.
- The boolean return value is not standardized across all underlying shortcuts yet; before adding new workflows, document whether a boolean means "finished", "started", or "action accepted".
- `farmItem`, `KillMonster`, `HuntMonster`, and `HuntMonsterQuest` delegate to the current `CombatManager` / `CombatEngine` workflow. The current combat implementation remains authoritative.
- The first `KillMonster` / `HuntMonster` wrappers do not yet expose all CoreBots parameters (notably `publicRoom`, logging flags, and map-specific bypass behavior). `Join` supports the public-room toggle for the join request, but map-specific bypass behavior still needs porting.
- New CoreBots routines should be added only after mapping the corresponding Skua helper's prerequisites, timeouts, cancellation, side effects, and failure behavior.
- Runtime/build validation remains required. This environment could not clone the repository to run Haxe compilation, so this change has not been compile-tested here.

## Next steps

1. Continue mapping actual `CoreBots`, `CoreFarms`, and `CoreAdvanced` helper contracts from the linked script repository.
2. Compare those contracts against the existing 224 ScriptBindings shortcuts and the new facade.
3. Add workflow helpers for confirmed gaps; avoid creating a second combat engine.
4. Add runtime smoke tests for namespace resolution and each delegated shortcut before expanding the surface.
