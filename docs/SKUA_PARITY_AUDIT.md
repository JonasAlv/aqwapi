# Skua parity audit (Haxe API)

> Working document for `feature/skua-parity-haxe`. Keep `main` as the clean baseline; do not merge this work into `main`.

## Goals and non-goals

- Use VibeSkua's script-facing interfaces as a **capability checklist**, not as a mandate to copy its internals.
- Keep the existing AQW Haxe/Flash integration and expand it where parity requires.
- Preserve the existing Haxe combat system. It already has substantial functionality (smart/custom combat, hunt/farm flows, skill modes, priorities, taunt/counter handling, aura pauses, potion support, and loadouts); do not replace it with Skua's combat implementation. Add compatibility wrappers only where needed.
- Build a CoreBots-style reusable helper layer so scripts express intent and delegate prerequisites/retries/waits to shared routines.
- Use [AE_source](https://github.com/JonasAlv/AE_source) when client behavior or data structures are unclear. Treat decompiled client behavior as evidence of client implementation, not proof that a server will accept every command.
- Keep transport/bridge work separate from in-runtime Haxe functionality; a manager method is not considered externally available until the chosen bridge exposes it.

## Status definitions

- **Present (verified):** matching implementation was found in Haxe source.
- **Partial:** related primitives exist, but parity of semantics, waits, events, options, or edge cases is not established.
- **Missing (verified):** searched source and found no implementation.
- **Unverified:** needs method-level comparison or runtime test. Do not call this missing yet.

This document is an initial source-based inventory, not a claim that every Skua method has been audited.

## Branch protection / workflow

1. All parity work is committed only to `feature/skua-parity-haxe`.
2. Never push these commits to `main` or merge this branch into `main`.
3. Before code changes to an existing manager, identify the current behavior and add a regression test or a documented manual verification case.
4. Combat changes must preserve current behavior unless a specific parity gap requires an additive adapter. Prefer delegating to `CombatManager` / `CombatEngine`.
5. Every feature entry in the matrix should link to its Skua interface/implementation and Haxe equivalent.
6. Use AE_source to investigate unknown game behavior; document the client source path and observed state/command. Avoid inferring server-side guarantees from client code.

## Confirmed Haxe foundations

Entry point: [Api.hx](../src/com/aqwapi/Api.hx). It exposes these managers/services:

| Capability | Existing implementation | Initial status | Notes |
|---|---|---|---|
| Map navigation / cell / pads / map items | `MapManager` | Present | Includes join/ensure, house and Tercess handling, fast travel, map items, collision/cutscene/death-spawn helpers. |
| Player state | `PlayerManager` | Present | Includes HP/MP, level, gold, username, alive/combat state, target, cell and pad. |
| Quests | `QuestManager` | Present | Quest ID/name resolution, quest DTOs, requirements/rewards, loading, acceptance/completion queues, status checks, auto-quest and reward choice helpers. |
| Combat / hunting | `CombatManager` + `CombatEngine` | Present; preserve | Includes smart/custom modes, attack/targeting, hunt/kill/farm-item, priorities, potion automation, taunt, counter handling, aura pauses and loadouts. |
| Skills and class modes | `SkillManager` | Present | Extensive class/mode storage, custom modes, combo/timeout configuration and class lookup; exact Skua parity unverified. |
| Inventory, bank, temporary inventory, gear snapshots | `InventoryManager` | Present | Item/quantity queries, equip, bank/unbank queues, temporary items, slot counts, gear save/restore, storage location and capacity helpers. |
| Drops | `DropManager` | Present | Pending/target drops, accept/pickup, AC drop handling and drop requests. |
| Shops | `ShopManager` | Present | Load, buy/sell, queued buys, pending counts, purchase requirements and favorite protection. |
| Monsters | `MonsterManager` | Present | Find/query/sort monsters, living cells, best target, aggro/pull/magnetize and on-screen entities. |
| Auras | `AuraManager` | Present | Aura lookup, stacks/remaining time, snapshots, counter aura checks, expired aura cleanup and auto-clean. |
| Enhancements | `EnhancementManager` | Present | Enhancement recommendations, special/proc/pattern lookup, queueing and cancellation. |
| Visual/performance | `VisualManager` | Present | Player/monster/weapon/ground/skill/spell effects and performance toggles. |
| Party | `PartyManager` | Present | Existing party operations; exact parity unverified. |
| Presets / blacklist | `PresetManager`, `BlacklistManager` | Present | Existing item preset and blacklist functionality. |
| Script lifecycle and HScript | `ScriptManager`, `HScriptEngine` | Present | Load/start/stop, tick scripts, lifecycle hooks, packet/zone/quest/inventory callbacks, status and cleanup. New `ScriptHandlers` and cooperative `ScriptWait` services are present on this branch; compile/runtime parity is pending. |
| Script function registration | `ScriptBindings`, `ScriptInterp`, `CoreBots`, `InventoryHelper` | Present / Partial | HScript has a shortcut registry, `core` / `CoreBots` facade, `invHelper` namespace and 224 named `bind(...)` shortcuts. Facade currently delegates to existing helpers; full CoreBots package parity is still pending. |

Source links:
- [ScriptBindings.hx](../src/com/aqwapi/scripting/ScriptBindings.hx)
- [ScriptInterp.hx](../src/com/aqwapi/scripting/ScriptInterp.hx)
- [CombatManager.hx](../src/com/aqwapi/managers/CombatManager.hx)
- [InventoryManager.hx](../src/com/aqwapi/managers/InventoryManager.hx)
- [QuestManager.hx](../src/com/aqwapi/managers/QuestManager.hx)
- [MapManager.hx](../src/com/aqwapi/managers/MapManager.hx)

## Existing HScript surface discovered

The current shortcut registry already has a broad set of script primitives. This matters because we should extend the current surface instead of duplicating helpers.

- **Map:** `join`, `joinHouse`, `ensureHouse`, `jump`, `ensureMap`, `ensureCell`, `getMapItem`, `isMap`, `isCell`, `isLoaded`, `fastTravel`, `ensureTercess`, `walkThroughWalls`, `skipCutscenes`.
- **Combat/hunting:** `hunt`, `kill`, `huntItem`, `huntMonster`, `farmItem`, `huntForItem`, `attack`, `stopCombat`, `ensureCombat`, `setTargetPriority`, `setHuntPriority`, `provokeAll`, `pauseOnAuras`, `enableTaunt`, `usePotion`, `autoPotion`.
- **Quests/story:** `quest`, `complete`, `completeChoose`, `ensureAccept`, `ensureQuest`, `acceptQuest`, `ensureComplete`, `completeQuest`, `loadQuest`, `loadQuests`, `ensureQuestsLoaded`, `storyKillQuest`, `storyMapItemQuest`, `storyChainQuest`, `autoQuest`.
- **Inventory/storage:** `hasItem`, `getItemCount`, `getInventory`, `getBankItems`, `equip`, `ensureEquipped`, `storeGear`, `restoreGear`, `bankAll`, `unbankPreset`, `unbankAllNonAcItems`, `getTempItems`, `hasTempItem`, `getItemLocation`, `getBankQuantity`.
- **Drops/shops/enhancement:** `acceptAllDrops`, `acceptAcDrops`, `getDrop`, `getDrops`, `buyItem`, `buyItems`, `sellItem`, `smartEnhance`, `enhanceItem`.
- **Player/aura/boost:** `level`, `username`, `hp`, `maxHp`, `mp`, `maxMp`, `gold`, `isAlive`, `isInCombat`, `factionRank`, `hasAura`, `getAuraStacks`, `getAuraRemaining`, `isBoostActive`, `useBoost`, `autoBoost`.
- **Runtime / diagnostics:** `sleep`, `stop`, `sendPacket`, `log`, `warn`, `error`, `notify`, `setDiagnostics`, `getDiagnostics`, `rateLimit`, `rateLimitDump`.
- **Visual/party/blacklist:** `lagKiller`, `hidePlayers`, skill/spell/monster rendering controls, `inParty`, `partyInvite`, `partyKick`, `partyLeave`, `partyTarget`, `addBlacklist`, `removeBlacklist`, `sellBlacklist`.

The shortcut list is based on `bind("...")` registrations in ScriptBindings; existence does not prove identical semantics to a Skua method.

The feature branch also exposes implemented managers through Skua-style PascalCase service names (`Bot.Player`, `Bot.Map`, `Bot.Quests`, `Bot.Inventory`, `Bot.Shops`, etc.) and adds a guarded PascalCase-to-lowerCamel fallback for member reads/calls. `PlayerManager` has explicit PascalCase aliases for verified state fields. This improves script compatibility but does not make unsupported services (`Options`, `Servers`, `GameProxy`, etc.) available, and must be runtime-tested with HScript.

## Skua script interface coverage checklist

The main Skua contract is [IScriptInterface.cs](https://github.com/NinjaXz/VibeSkua/blob/main/Skua.Core.Interfaces/Scripts/IScriptInterface.cs). It aggregates these service families. The matching Haxe coverage below is a first-pass mapping.

| Skua surface | Haxe equivalent / current status | Follow-up audit |
|---|---|---|
| `Map` | `MapManager`; **Present / Partial** | Compare loading flags, room ID, player lists, map items cache, JoinIgnore/JoinPacket and exact wait semantics. |
| `Player` | `PlayerManager`; **Present / Partial** | Compare player metadata, movement, position, classes/equipment, state events and methods not shown in first-pass property sample. |
| `Combat`, `Kill`, `Hunt`, `Auto`, `Skills` | `CombatManager`, `CombatEngine`, `MonsterManager`, `SkillManager`; **Present / preserve combat** | Match helper names by adapters. Do not replace current combat logic; test existing hunt/farm and custom rotations before changes. |
| `Quests` | `QuestManager`; **Present / Partial** | Compare quest registration/auto-complete, cached quest database, status, full prerequisite checks and reward selection. |
| `Inventory`, `TempInv`, `Bank`, `House`, `InvHelper` | `InventoryManager`, `ScriptBank`, `ScriptTempInv`, `ScriptHouseInv`, `InventoryHelper`; **Partial** | Distinct first-pass `Bot.Bank`, `Bot.TempInv`, and `Bot.House` facades now expose container-specific item lists/quantities/presence checks. Bank transfer and house-specific workflows plus inherited container methods still need parity tests. Lowercase `bank` remains the legacy `Api.inventory` binding. |
| `Drops` | `DropManager`; **Present / Partial** | Compare filtering, pickup waits, target drops, rejection rules, AC protections and event handling. |
| `Shops` | `ShopManager`; **Present / Partial** | Compare shop loading, buy/sell result waits, item resolution and purchase prerequisites. |
| `Monsters` | `MonsterManager`; **Present / Partial** | Compare player/monster DTO fields, query semantics, alive filters and priority rules. |
| `Self`, `Target`, `AuraMonitor`, `UltraBossHelper` | `AuraManager` and combat aura handling; **Partial / Unverified** | Add an aura-change event/monitor facade and ultra-boss helpers only after inspecting exact interfaces and current counter system. |
| `Boosts` | boost shortcuts exist; **Partial** | Find the owning implementation, compare consumption, active duration, cooldown and retry semantics. |
| `Reputation` | `factionRank` shortcut found; **Partial** | Audit rank lookup and reputation-farming helpers. |
| `Wait` | `ScriptWait` added on feature branch; **Partial** | Cooperative waits cover map/cell/combat/quest/item/drop/bank conditions; the latest pass adds generic value predicates and action/skill cooldown checks and fixes the inventory-to-bank wait condition. They do not suspend the current stack; buy/sell waits now use a best-effort inventory-signature fallback, while exact acknowledgement semantics and some Skua overloads remain open. |
| `Events` | dispatcher and HScript lifecycle callbacks exist; **Partial** | Compare map, quest, inventory, packet, aura and script-stopping event contracts, registration and cleanup. |
| `Handlers` | `ScriptHandlers` / `ScriptHandler` added on feature branch; **Partial** | Skua-style registration/removal and recurring/one-shot callbacks are implemented cooperatively; runtime compilation and timing parity remain unverified. |
| `Options`, `Lite`, `Config` | manager settings/presets/config paths exist; **Partial / Unverified** | Compare mutable runtime options, per-script config persistence and safe timing controls. |
| `Servers`, `Send`, `GameProxy`, `Accounts` | packet shortcut and `TransportAdapter` exist; **Partial / Unverified** | Inspect implementation and bridge exposure separately; do not expose credentials or assume all proxy features exist. |
| `Manager`, `ShouldExit`, `Sleep`, `StopAsync`, `Schedule`, `Log`, dialogs | `ScriptManager`, `HScriptEngine`, `ApiLogger`; **Partial** | Define consistent stop/cancel semantics, scheduled callback cleanup, dialogs and error reporting. |
| `Stats`, `Flash`, `Version`, `Random`, `SellJunk` | diagnostics/Flash integration may cover parts; **Unverified** | Locate exact implementation or explicitly mark unsupported if not relevant to Linux host. |

## CoreBots-style helper layer

Do not port Skua's combat algorithm just to provide similar script APIs. The recommended design is:

1. **Low-level managers remain the source of truth:** map, player, quest, inventory, combat, drops, shops, monsters, skills, auras, enhancements.
2. **Compatibility facade:** Skua-like names and return conventions that delegate to existing managers.
3. **CoreBots workflow helpers:** stateful multi-step operations that manage prerequisites, wait/retry/timeout behavior, cancellation and cleanup.
4. **Script bindings:** expose a curated stable namespace to HScript. Reuse the existing `ScriptBindings` registry and `ScriptInterp.resolve` namespace model rather than adding a parallel dispatcher.

Initial helper families to design (not yet claimed implemented as a CoreBots namespace):

- **Prerequisites:** ensure map/cell, ensure inventory item, ensure quest loaded/accepted/completed, ensure gear/class equipped.
- **Farming:** farm item until quantity, kill until count, collect map items, hunt quest requirements, farm with preferred monster/cell/map.
- **Quest chains:** resolve reward choice, check all requirements, gather missing requirements, accept/complete safely, stop on failure or cancellation.
- **Storage/space:** ensure item is available from inventory/bank/temp/house, preserve/restore gear, free inventory space before rewards.
- **Lifecycle/safety:** condition wait with timeout, stop checks, operation cooldowns, bounded retries, structured result/reason, cleanup after errors.
- **Combat integration:** delegate to existing combat/hunt engine; add wrappers for class/mode/loadout selection only where parity requires them.

Prefer APIs that return an explicit state/result rather than ambiguous booleans for multi-tick workflows, e.g. `RUNNING`, `DONE`, `FAILED`, `CANCELLED`. Keep current boolean primitives intact for backward compatibility.

## AE_source investigation guide

Start with:
- [AE_source docs index](https://github.com/JonasAlv/AE_source/blob/main/docs/README.md)
- [Gameplay/state model](https://github.com/JonasAlv/AE_source/blob/main/docs/GAME_SYSTEMS.md)
- [Protocol reference](https://github.com/JonasAlv/AE_source/blob/main/docs/PROTOCOL.md)
- [Developer guide](https://github.com/JonasAlv/AE_source/blob/main/docs/DEVELOPER_GUIDE.md)
- Main client: `decompiled/Game3098r27/scripts/Game.as`
- World state: `decompiled/Game3098r27/scripts/World.as`

When an API behavior is unclear, document:
- relevant client source file and function
- state objects/fields read or mutated
- command/packet sent and expected response
- whether Haxe currently uses that field/command
- behavior that still needs runtime verification

Do not treat the decompiled client's implementation as a guarantee of current server-side behavior.

## First implementation milestones

- [ ] Enumerate all Skua interface files and extract properties/method signatures into a detailed checklist.
- [ ] Extract Haxe public methods and ScriptBindings shortcuts per manager.
- [ ] Mark each entry Present / Partial / Missing / Unverified with evidence links.
- [ ] Write regression cases for existing combat, map joining, quest completion and inventory/bank operations before touching behavior.
- [ ] Implement the remaining foundational gaps: standardized workflow outcomes, cancellation, and remaining Skua Wait overloads. (Initial `CoreBots` facade, timed handlers, inventory helper, and cooperative waits now exist on this branch.)
- [ ] Implement CoreBots-style workflows using current managers and combat engine.
- [ ] Verify representative scripts end-to-end in the actual Flash runtime and bridge.
- [ ] Keep all commits on this feature branch; do not merge into `main`.
