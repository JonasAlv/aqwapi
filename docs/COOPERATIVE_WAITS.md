# Cooperative Wait helpers

The feature branch now exposes a first-pass wait service through `wait` and `Bot.Wait`, implemented in `src/com/aqwapi/scripting/ScriptWait.hx`.

## Available methods

- `ForTrue(key, predicate, timeoutMs)`
- `ForMapLoad(mapName, timeoutMs)`
- `ForCellChange(cell, timeoutMs)`
- `ForCombatExit(timeoutMs)`
- `ForQuestAccept(questId, timeoutMs)`
- `ForItemEquip(itemNameOrId, timeoutMs)`
- `ForBankLoad(timeoutMs)`
- `ForBankToInventory(itemNameOrId, timeout)` — Skua-compatible script-facing signature; lower-camel `forBankToInventory(item, quantity, timeoutMs)` retains quantity-aware internals.
- `ForInventoryToBank(itemNameOrId, timeout)` — waits for bank quantity to appear; lower-camel `forInventoryToBank(item, quantity, timeoutMs)` retains quantity-aware internals.
- `ForBankToHouseInventory(itemNameOrId, timeout)`
- `ForHouseInventoryToBank(itemNameOrId, timeout)`
- `For(predicate, value, timeout, key)` and cooperative `ForAsync(predicate, value, timeout, key)`
- `IsActionAvailable(action)` and `ForActionCooldown(action, timeout)`
- `ForSkillCooldown(index, timeout)`
- `ForTrueAsync(predicate, timeout, key)` (cooperative alias, not a true async task)
- `ForItemBuy(timeout)` and `ForItemSell(timeout)` (cooperative inventory-signature detection after a recorded shop request)
- `reset(key)`, `clear()`, `lastStatus`, `defaultTimeoutMs`

Lower-camel names are also available. Example:

```haxe
var waitPhase = 0;

function onTick() {
    if (waitPhase == 0) {
        if (!Bot.Wait.ForMapLoad("battleon", 10000)) return;
        waitPhase = 1;
    }
    if (waitPhase == 1) {
        if (!Bot.Wait.ForCellChange("Enter", 5000)) return;
        waitPhase = 2;
    }
    if (waitPhase == 2) {
        // Continue once; the phase prevents repeating this action every tick.
        waitPhase = 3;
    }
}
```

## Skua-compatible predicates adjusted in this pass

- `ForPickup(item)` checks that the matching drop is no longer present; already owning the same item is not enough to satisfy the wait.
- `ForMonsterDeath()` follows Skua's documented behavior of waiting for no target selected. If the selected target has zero HP, it clears that dead target; it does not cancel a living target.
- `ForInventoryToBank(item)` waits for the item to disappear from normal inventory, matching Skua's contract. The lower-camel `forInventoryToBank(item, quantity, timeoutMs)` remains available for callers who specifically need to verify that the bank quantity reached a threshold.

## Semantics

- Methods are **cooperative predicates**, not blocking calls. Call them repeatedly from `onTick`; continue only when the result is true.
- `lastStatus` is `pending`, `done`, or `timeout`. A timeout remains latched for that operation key until the condition becomes true or the state is reset/cleared.
- A negative timeout uses `defaultTimeoutMs` (10 seconds by default); zero means no timeout.
- The service state is cleared at script start and after `onStop`.
- It does not suspend the current call stack, so it is not source-compatible with sequential C# scripts that expect Wait to block. `ForAsync`/`ForTrueAsync` are cooperative aliases, not true async tasks. `ForItemBuy`/`ForItemSell` are now implemented as best-effort checks for a change to the normal-inventory signature after the corresponding Haxe shop request. This can detect fast changes because the baseline is captured before sending, but it is not a server acknowledgement and unrelated inventory changes can satisfy it; replace with explicit response events if the bridge/game hook can reliably expose them.
- The host timer currently runs at 100ms by default; waits can only observe conditions on those ticks.

## Validation still required

- [ ] Build the normal SWF/SWC target.
- [ ] Confirm global `wait` and `Bot.Wait` namespace resolution.
- [ ] Verify all success/timeout/reset cases and no state leaks between scripts.
- [ ] Compare timeout defaults with Skua's per-action timeouts before adding more overloads.
- [ ] Verify action-lock field names (`ts`/`cd`) against the target client build.
- [ ] Verify `ForSkillCooldown` with custom skill modes and disabled skills.
- [x] Add `ForItemBuy` / `ForItemSell` as cooperative waits using pre-request inventory snapshots.
- [ ] Replace the inventory-signature fallback with explicit buy/sell acknowledgement events if a reliable in-runtime or bridge event can be wired; verify unrelated inventory changes cannot produce false success.
