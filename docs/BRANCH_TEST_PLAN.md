# Feature branch verification plan

Run these checks against `skua-haxe` before using the new helpers in real scripts. No automated test framework or Haxe compiler was available in the current environment, so these are pending validation steps rather than passed tests.

## Build / namespace smoke tests

- [ ] Build the repository's normal SWF/SWC target.
- [ ] Load an HScript containing `CoreBots.EnsureMap(...)`, `CoreBots.EnsureItems(...)`, `CoreBots.CheckInventory(...)`, and `Bot.InvHelper.Check(...)`.
- [ ] Confirm service aliases resolve: `Bot.Player.Health`, `Bot.Map.Loaded`, `Bot.Map.Join(...)`, `Bot.Quests`, `Bot.Inventory`, `Bot.Shops.IsLoaded`, `Bot.Shops.BuyItem(...)`, `Bot.Monsters`, `Bot.Skills`, `Bot.Wait`, and `Bot.Handlers`.
- [ ] Confirm PascalCase player aliases return the same values as lower-camel Haxe properties (for example `Bot.Player.Health == Bot.Player.hp`, `Bot.Player.CurrentClass == Bot.Player.className`).
- [ ] Confirm `Bot.Inventory.MiscSlots`, `MiscUsedSlots`, and `MiscFreeSlots` agree with the lower-camel capacity methods.
- [ ] Confirm `Bot.Bank.Contains(...)` checks bank-only quantities, `Bot.TempInv.Contains(...)` checks temporary inventory only, and `Bot.House.Contains(...)` checks house storage only.
- [ ] Confirm `Bot.Bank.Load()` returns without blocking and `Bot.Wait.ForBankLoad()` reports completion only after bank data is available.
- [ ] Confirm the legacy lowercase `bank` binding still resolves to `Api.inventory` for existing scripts.
- [ ] Load a script using both `handlers.registerHandler(...)` and `Bot.Handlers.RegisterHandler(...)`.
- [ ] Confirm all new Haxe files are included in the SWC output.

## Inventory helper

- [ ] Item already in normal inventory at required quantity returns true.
- [ ] Item only in temp inventory returns true.
- [ ] Item only in house inventory returns true and is not falsely reported as moved to normal inventory.
- [ ] Item only in bank with `moveToInventory=false` returns true when bank quantity is sufficient.
- [ ] Item only in bank with `moveToInventory=true` queues a withdrawal, returns false while pending, and returns true only when the required quantity is in inventory.
- [ ] Multiple bank items are queued while a withdrawal operation is already running without restarting house-load polling.
- [ ] Name lookup and numeric ID lookup work when bank data is represented by `bankItems`, `BankArray`, or `items`.
- [ ] Partial quantities, empty lists, duplicate item IDs/names, inventory-full state, and unavailable bank data behave predictably.

## Cooperative waits (Skua parity additions)

- [ ] Skua-compatible `ForInventoryToBank(item)` stays false while the item remains in normal inventory and succeeds when it disappears; lower-camel `forInventoryToBank(item, quantity)` separately verifies bank quantity.
- [ ] `ForBankToInventory(item)` uses Skua-compatible timeout argument semantics and waits for inventory presence.
- [ ] `ForBankToHouseInventory(item)` waits for house storage presence; `ForHouseInventoryToBank(item)` waits for house storage absence.
- [ ] `For(predicate, value)` and `ForAsync(predicate, value)` are called over successive ticks and never block the Flash/UI thread.
- [ ] `IsActionAvailable(action)` returns false for unknown/missing lock data and true only after the game action cooldown has elapsed.
- [ ] `ForActionCooldown(action)` applies `GameActionTimeout` when `OverrideTimeout` is enabled.
- [ ] `ForSkillCooldown(index)` follows the existing `CombatManager.canUseSkill` behavior.
- [ ] `ForPickup(item)` waits for the matching drop to disappear even if the player already owns the same item.
- [ ] `ForMonsterDeath()` matches Skua's no-target-selected condition; a dead target that remains selected does not satisfy the wait.
- [ ] `ForItemBuy()` / `ForItemSell()` detect a normal-inventory signature change after the matching request; test successful, rejected, throttled, and unrelated inventory-change cases. Treat unrelated changes satisfying the wait as a known limitation until explicit acknowledgement events are wired.

## Timed handlers

- [ ] A handler returning true repeats at the requested interval (subject to the 100ms host tick).
- [ ] A handler returning false is removed.
- [ ] `RegisterOnce` invokes once and removes itself.
- [ ] `Remove(name)`, `Remove(handler)`, and `Clear()` behave correctly.
- [ ] Handlers continue during `sleep()` waits.
- [ ] Handler exceptions are logged and do not break later handlers.
- [ ] Script stop clears registered handlers after `onStop` runs.

## CoreBots compatibility wrappers

- [ ] `EnsureAccept` returns false while a quest is only queued and true after it is in progress.
- [ ] `EnsureComplete` waits for required items in inventory/temp/house/bank and does not report completion before the quest is actually completed.
- [ ] `KillMonster` / `HuntMonster` navigate to the requested map/cell before delegating combat.
- [ ] Item farming stops when the requested item/quantity is satisfied.
- [ ] Existing combat modes, custom rotations, target priorities, taunt/counter behavior, aura pauses, potion automation, and gear/loadout helpers behave exactly as before.

## Regression constraints

- [ ] Compare the feature branch's behavior to `main` before changing existing manager logic.
- [ ] Keep all work on `feature/skua-parity-haxe`; do not merge to `main`.
- [ ] For each new CoreBots helper, record return semantics, whether it must be called every tick, prerequisites, timeout/cancellation behavior, and cleanup.

## Latest CoreBots / map / bank additions

- [ ] Confirm top-level isQuestComplete and CoreBots.IsQuestComplete are false for an accepted but not-yet-completed quest, even if canComplete is true; confirm true only after the completed quest state is recorded.
- [ ] Confirm CoreBots.CheckSpaces counts only items not already present across normal/temp/house/bank storage and never starts banking as a side effect.
- [ ] Confirm CoreBots.Unbank / ToBank enqueue transfers without issuing duplicate queue entries across repeated calls.
- [ ] Exercise Bot.Bank.Open when the Bank popup is closed and already open; the second call must not close it.
- [ ] Test Bot.Bank.Swap / EnsureSwap with valid items, already-swapped items, equipped/unbankable items, full inventory, bank-load delay, and rejected transfers. Confirm true only after the expected local quantity changes.
- [ ] Test a bank swap timeout: it must remain latched, must not queue the same transfer each tick, and ResetSwap / CoreBots.ResetSwapBank must explicitly allow a retry.
- [ ] Test Map.PlayerExists, TryGetPlayer, GetPlayer, Players, PlayerNames, PlayerCount, CellPlayers and Cells with self-only, other-player, empty, and cell-transition states.
- [ ] Verify Map.JoinPacket sends the requested map/cell/pad without private-room suffix rewriting or normal join cooldown logic; validate this only in a test account/client.
- [ ] Test CoreBots.EnsureLoadAndBuyItem with the wrong shop initially loaded, delayed shop loading, successful purchase, unmet purchase requirements, no free slots, server rejection, and timeout. Confirm one purchase request per workflow and explicit reset before retry.
- [ ] Confirm the existing CombatManager / CombatEngine modes remain unchanged; new helpers must only delegate to them.

## Partial Bot.Send facade

- [ ] Confirm Bot.Send.Packet sends String packets through sfc.sendString and uses the matching SFC method for supported packet types.
- [ ] Confirm Bot.Send.ClientPacket reports an unavailable helper rather than pretending the packet was sent when the current game build exposes no sendClientPacket function.
- [ ] Verify ClientEvent/ClientGuild/ClientModerator/ClientServer/ClientWarning/ClientWhisper/ClientZone chat packet formatting against the current game client.
- [ ] Verify Bot.Send.Whisper packet format on a test account; this is a server-bound message, not a client-only message.
- [ ] Keep packet spam methods unimplemented until a cooperative cancellation contract is added; do not add blocking or unbounded packet loops.

- [ ] Verify Bot.Reputation.GetRank(faction) matches the existing PlayerManager lookup and HasRank compares the returned rank to the requested threshold; confirm unknown factions return 0/false.
- [ ] Verify setting Bot.Bank.Loaded=true only succeeds when client bank data exists, and setting false clears the local loaded flag without corrupting the bank item data.
