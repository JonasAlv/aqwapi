# Skua parity: method-level backlog

This is the next-level checklist beneath [SKUA_PARITY_AUDIT.md](SKUA_PARITY_AUDIT.md). Items below are derived from Skua interface declarations. "Needs audit" means we must compare signatures **and behavior** against the Haxe implementation before classifying it as missing.

## Priority 0 — protect working behavior

- [ ] Capture a baseline for existing `CombatManager` / `CombatEngine`: smart mode, custom rotation, class/mode selection, target priorities, hunting, item farming, taunt, counter handling, aura-triggered pauses, auto-potions, loadout/equipment helpers.
- [ ] Add no replacement combat algorithm as part of parity work. Map Skua `Combat`, `Kill`, `Hunt`, `Auto`, and `Skills` onto existing behavior with thin adapters where possible.
- [ ] Verify existing HScript scripts still work after every additive change.

## Priority 1 — waits and action completion

Skua's `IScriptWait` exposes configurable polling and category-specific timeouts:

- `WAIT_SLEEP`, `OverrideTimeout`
- `PlayerActionTimeout`, `DropActionTimeout`, `GameActionTimeout`, `ItemActionTimeout`, `MapActionTimeout`, `MonsterActionTimeout`, `QuestActionTimeout`
- `For(Func<object>, object, timeout)` and `ForAsync(..., CancellationToken)`
- `ForActionCooldown(GameActions|string)`
- `ForBankLoad`, `ForBankToInventory(name/id)`, `ForBankToHouseInventory(name/id)`, `ForInventoryToBank(name/id)`
- `ForCellChange`, `ForCombatExit`, `ForDrop(name/id)`, `ForItemBuy`, `ForItemEquip(name/id)`, `ForItemSell`, `ForMapLoad`, `ForMonsterSpawn(name/id)`, `ForPickup(name/id)`, `ForPlayerPosition`, `ForQuestAccept`, `ForQuestComplete`, and `ForSkillCooldown` (verify the full source for overloads).

**Haxe evidence:** `HScriptEngine.sleep(ms)` only advances a `waitTimer` and defers later `onTick` calls; it does not suspend the current call stack. A first-pass `ScriptWait` service now covers true predicates, map load, cell change, combat exit, quest acceptance, item equip, bank load, and bank/inventory transfer conditions. See [COOPERATIVE_WAITS.md](COOPERATIVE_WAITS.md). It is not equivalent to Skua synchronous waits; do not block the Flash UI thread. Continue using cooperative, tick-driven state machines and keep `sleep` semantics backward-compatible.

- [ ] Extract every wait overload and its default timeout from Skua's `IScriptWait.cs`.
- [ ] Map to existing manager queues and event hooks.
- [x] Add a first-pass shared cooperative wait service; compile/runtime validation and the remaining Skua overloads are still pending.
- [ ] Test success, timeout, script stop, map transition, and target disappearance.

## Priority 2 — inventory and storage semantics

Skua deliberately exposes separate `Inventory`, `TempInv`, `Bank`, `House`, and `InvHelper` surfaces.

### Confirmed Skua bank contract examples

- `Loaded`, `Open()`, `Load(waitForLoad)`
- `Swap(inventory item, bank item)` overloads
- `EnsureSwap(..., loadBank)`
- `ToInventory(item)` and `EnsureToInventory(name/id, loadBank)`

### Confirmed Skua inventory contract examples

- `HasCategories`, `MiscSlots`, `MiscUsedSlots`, `MiscFreeSlots`
- `GetPool(item)`, `HasSpaceFor(item, quantity)`, `CanBank(item)`, `IsFavorited(itemId)`

**Haxe evidence:** `InventoryManager` already contains inventory/bank/temp-item queries, bank/unbank queues, gear snapshots and restore, storage location, bank slot counts, item capacity, favoriting and bankability methods. A first-pass `InventoryHelper` with `Check` / `HasAll` / `HasAny` now exists at `Bot.InvHelper` / `invHelper`; see [INVENTORY_HELPER.md](INVENTORY_HELPER.md). Treat the manager as a strong existing implementation, not a rewrite target.

- [ ] Compare every `IScriptBank` member against `InventoryManager` and shortcut names.
- [ ] Compare every `IScriptInventory` member and distinguish bankable items, temporary items, house items, quest quantity, and normal inventory. The helper is first-pass and still needs runtime tests.
- [ ] Compare `IScriptTempInv`, `IScriptHouseInv`, and `IScriptInventoryHelper` one by one.
- [ ] Ensure helper return values mean the same thing as Skua (attempt started vs action completed vs item verified).
- [ ] Check capacity/free-space behavior before quest reward selection or shopping.

## Priority 3 — map, monsters, kill and hunt

### Map contract examples from `IScriptMap`

- Properties: `LastMap`, `Loading`, `FilePath`, `FileName`, `Name`, `FullName`, `Loaded`, `RoomID`, `PlayerCount`, `Cells`, `PlayerNames`, `Players`, `CellPlayers`.
- Actions: `Reload()`, `Join(map, cell, pad, ignoreCheck, autoCorrect)`, `JoinIgnore(map)`, `JoinPacket(map, cell, pad)`, `Jump(cell, pad, autoCorrect, clientOnly)`, `GetMapItem(id/quantity)`, `PlayerExists(name)`, `TryGetPlayer(name)`, `GetPlayer(name)`, `FindMapItems(forceRefresh)`, `ClearMapItemsCache(map)`.

**Haxe evidence:** `MapManager` has join/jump/reload, map items, loaded/name/room ID, cells/pads, private rooms, Tercess navigation, fast travel, collision and cutscene controls. Player lists, file path/name, map-item cache semantics, and packet-only joins need explicit comparison.

### Kill and hunt contracts

Skua `IScriptKill` and `IScriptHunt` provide overloads for monster by name/ID/object, optional cancellation token, `ForItem`, `ForItems`, and hunt priority selection.

**Haxe evidence:** `CombatManager` already has `hunt`, `kill`, `farmItem`, `huntForItem`, `huntQuest`, target priorities and combat cancellation. `MonsterManager` has living-monster lookup, cell resolution, sorting and target selection.

- [ ] Preserve existing combat behavior; add adapters for Skua-style overloads rather than rewriting the engine.
- [ ] Define a cancellation contract for long-running HScript helpers.
- [ ] Compare whether a helper waits until the goal is achieved or only starts the action.
- [ ] Test target dies, target disappears, map changes, item drops late, and script stops.

## Priority 4 — quests, drops and shops

### Quest contract

Skua `IScriptQuest` includes active/completed/tree/cached quest collections; registered quests and reward choices; `RegisterQuests`, `UnregisterQuests`; `Accept` / `EnsureAccept`; `CanComplete` / `CanCompleteFullCheck`; `Complete` / `EnsureComplete`; and status/availability queries.

**Haxe evidence:** `QuestManager` already resolves quest IDs by ID/name, reads requirements/rewards, loads quests, accepts/completes via queues, checks status and runs auto-quest. The HScript shortcuts `quest`, `complete`, `completeChoose`, `ensureAccept`, `ensureComplete`, `storyKillQuest`, `storyMapItemQuest`, and `storyChainQuest` already provide multi-tick workflow patterns.

- [ ] Compare registered quest behavior and auto-turn-in semantics.
- [ ] Compare full prerequisite checks, reward-choice behavior, and retry limits.
- [ ] Check quest completion behavior under combat and inventory-full conditions.

Skua `IScriptDrop` includes current drop information, pickup/reject filters, interval, `Add` / `Remove`, `Start` / `Stop`, `Pickup(name/id)`, `PickupAll(skipWait)`, `RejectAll(skipWait)`, and `RejectExcept`.

**Haxe evidence:** `DropManager` has pending/target drops, accept/pickup, AC handling, and drop requests. Compare filter semantics, rejection defaults, and wait behavior.

Skua `IScriptShop` exposes current shop state plus loading, buying and selling operations.

**Haxe evidence:** `ShopManager` has shop loading, queued buying, selling, loaded-shop state, purchase-requirement checks and favorite protection. `ForItemBuy` / `ForItemSell` now detect a normal-inventory signature change after a recorded request. This is not an authoritative server acknowledgement and needs live testing or a proper response event. Compare item resolution, queue behavior, retries and result waits.

## Priority 5 — events, handlers, runtime options and integration

- [ ] Compare `IScriptEvent` events and registration/unregistration behavior against `Api.dispatcher` and HScript callbacks (`onStart`, `onTick`, `onStop`, `onPacket`, `onZoneEntered`, `onQuestUpdated`, `onInventoryChanged`).
- [x] Add first-pass `ScriptHandlers` / `ScriptHandler` timed handler registration, one-shot handlers, removal, clearing, and lifecycle cleanup. [Runtime/build validation pending](SCRIPT_HANDLERS.md). Compare exact timing and exception semantics before calling this full parity.
- [ ] Compare `IScriptOption`, `IScriptLite`, and `Config` against Haxe settings/presets and define persistence/default semantics.
- [ ] Compare `IScriptServers`, `IScriptSend`, `GameProxy`, and `Accounts`; separate in-game commands from host/bridge features.
- [ ] Compare `IScriptFaction`, `IScriptBoost`, `IScriptBotStats`, `IFlashUtil`, `IUltraBossHelper`, and `IAuraMonitorService`.
- [ ] For host-only Skua features (desktop dialogs, Flash UI controls, proxy capture, account tabs), decide whether to adapt to the Linux host, expose a capability boundary, or document as unsupported. Do not pretend they are Haxe game operations.

## CoreBots-style helpers: what exists and what is not yet established

Haxe already has stateful helper patterns in ScriptBindings, including `quest`, `mapItem`, `ensureMapItem`, `complete`, `completeChoose`, `storyKillQuest`, `storyMapItemQuest`, `storyChainQuest`, `farmItem`, `huntForItem`, `ensureEquipped`, `ensureRestored`, and `ensureQuestsLoaded`. Several return a boolean that scripts can check on successive ticks.

The first namespaced Haxe facade now exists at `src/com/aqwapi/scripting/CoreBots.hx`, accessible as `CoreBots` or `core`. It delegates to existing shortcuts rather than duplicating logic. This is only an initial facade: next map actual helper routines from Skua script packages (`CoreBots`, `CoreFarms`, `CoreAdvanced`, etc.) and add workflows for confirmed gaps, centralizing prerequisites, timeouts, cancellation, and cleanup.

A helper that takes multiple ticks must document its contract:
- called once to start, or called each `onTick` until complete;
- whether `true` means started or finished;
- what happens on timeout, script cancellation, or unavailable prerequisites;
- whether it changes combat state, map, gear, or global options.

## Source of truth and validation

- VibeSkua interfaces define the expected script-facing shape.
- VibeSkua concrete `Skua.Core/Scripts/*` implementations define current behavior and edge cases.
- Haxe managers and `ScriptBindings` define current local behavior.
- [AE_source](https://github.com/JonasAlv/AE_source) explains client object state and observed commands where needed.
- Runtime tests establish whether the client/server accepts an operation.

No source in this checklist should be treated as proof that an operation is absent until its Haxe manager, binding, and existing helper script usage have been checked.

## Progress update — additive implementation pass

Implemented on this branch since the initial backlog:
- Added CoreBots facade adapters for choice-reward completion, story quest workflows, quest status/requirements, map-item collection, storage checks, drops, shop actions, boosts, loadouts, house entry, fast travel, and multi-quest completion.
- Added Skua-style Map player queries (Players, PlayerNames, PlayerCount, CellPlayers, PlayerExists, TryGetPlayer/GetPlayer), Cells, and a low-level JoinPacket that bypasses private-room rewriting and normal join cooldown logic.
- Added Player.Alive, Player.InCombat, Player.Loaded, and Player.Playing aliases backed by existing Haxe avatar/state values.
- Added a partial Bot.Send facade for server-bound Packet, client packet/chat messages, and Whisper; it only calls client helpers when the current build exposes them. Packet spam/cancellation and full client-side API parity remain unimplemented.
- Added a partial Bot.Reputation facade exposing GetRank/HasRank through PlayerManager's existing faction-rank lookup. Faction enumeration and reputation farming are still unimplemented.
- Added non-destructive CheckSpaces preflight plus Unbank/ToBank wrappers. The Haxe signature cannot mirror C#'s ref-counter overload exactly, so CheckSpaces returns whether available free slots appear sufficient.
- Added cooperative Bot.Bank Swap/EnsureSwap and CoreBots.SwapBank. It sequences the existing bank queues, observes local inventory/bank quantity changes, and has a bounded per-phase timeout. It is not an authoritative server acknowledgement; validate in a live client before relying on it for valuable items.
- Made Bot.Bank.Open idempotent; it no longer toggles the bank closed when the bank UI is already open. Bot.Bank.Loaded is now settable through a guarded setter that only marks the bank loaded when client bank data exists.
- Added CoreBots.EnsureLoadAndBuyItem as a cooperative workflow: request the shop, queue one purchase, wait for the requested inventory quantity increase, and latch timeout failures until explicitly reset.
- Fixed the top-level isQuestComplete binding to call hasBeenCompleted rather than canComplete; turn-in eligibility and completed state are different predicates.

Still unverified / missing after this pass:
- Full Haxe build and Flash runtime tests. This environment has no Haxe compiler installed and no CI workflow/status was returned for the new commits.
- Exact parity of inherited inventory interfaces (TryGetItem/Find/IsMaxStack), bank swap edge cases, transfer acknowledgements, item quantities/IDs, and bank-to-house flows.
- Shop workflow purchase prerequisites, favorite protection, maximum-quantity semantics, server rejection, and false-positive inventory changes.
- Full CoreBots/CoreFarms/CoreAdvanced helper inventory, especially configuration/options, retry policy, rest/class equipment, quest registration/abandonment, house-to-bank transfer, and game-specific boss/workflow helpers.
- Remaining IScriptInterface services with no honest Haxe equivalent yet: Flash utility/game-object access, Options/Lite/Config parity, Servers/Accounts, GameProxy, Stats, AuraMonitor, UltraBossHelper, and host/UI-only features.

Combat remains protected: all new farming and hunting helpers delegate to the existing CombatManager/CombatEngine. No replacement combat algorithm was added.
