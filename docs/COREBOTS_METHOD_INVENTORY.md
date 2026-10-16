# External Skua CoreBots library inventory

Reference branch: [BrenoHenrike/Scripts — Skua](https://github.com/BrenoHenrike/Scripts/tree/Skua)

Source files inspected:
- [CoreBots.cs](https://github.com/BrenoHenrike/Scripts/blob/Skua/CoreBots.cs) — approximately 10,285 lines.
- [CoreFarms.cs](https://github.com/BrenoHenrike/Scripts/blob/Skua/CoreFarms.cs) — approximately 3,965 lines.
- [CoreAdvanced.cs](https://github.com/BrenoHenrike/Scripts/blob/Skua/CoreAdvanced.cs) — approximately 3,427 lines.

These are **reusable script libraries included by scripts**, not just the VibeSkua backend interface. Porting the entire files line-for-line is not the plan: many methods contain blocking loops, C# task waits, UI-specific settings, and game-specific workflows. Extract the reusable behavior and reimplement it cooperatively in Haxe.

## CoreBots.cs capability groups

| Group | Observed helper methods / fields | Existing Haxe coverage | Next step |
|---|---|---|---|
| Runtime options | `ActionDelay`, `ExitCombatDelay`, `HuntDelay`, `AcceptandCompleteTries`, `LoadedQuestLimit`, `PrivateRooms`, `PrivateRoomNumber`, `CustomStopLocation`, class/gear settings | Map/private-room controls, presets, skill modes, inventory gear snapshot/restore | Define a Haxe config model with defaults and persistence; avoid global settings being silently changed by helper calls. |
| Inventory prerequisites | `CheckInventory` scalar/array overloads, `CheckSpaces`, `Unbank`, `ToBank`, `ToHouseBank` | `InventoryManager`, new `InventoryHelper`, bank queues and slot/capacity helpers | Verify item-count semantics and house/bank actions; add space checks that do not claim queued actions already completed. |
| Shop / buying | `BuyItem`, `_BuyItem`, `MaxBuyQuant`, `GetShopItems`, `parseShopItem`, `SellItem` | `ShopManager` load/buy/sell queues, unmet requirements | Add an ensure-buy workflow with explicit pending/completed/failure results and inventory-space prerequisites. |
| Quest workflows | `RegisterQuests`, `EnsureAccept`, `EnsureComplete`, `EnsureCompleteChoose`, `EnsureCompleteMulti`, `EnsureLoad`, `ChainComplete`, `AbandonQuest`, reward helpers | `QuestManager` and HScript shortcuts `quest`, `complete`, `completeChoose`, `storyChainQuest`, auto-quest | Compare quest prerequisites, reward selection, registration and retry policies. Initial Haxe `CoreBots.EnsureAccept/EnsureComplete/EnsureLoad` wrappers exist. |
| Combat / item farming | `KillMonster`, `HuntMonster`, `HuntMonsterMapID`, `HuntMonsterQuest`, `_KillForItem`, boss-specific helpers | Existing `CombatManager` / `CombatEngine` hunt/kill/farm methods, monster query/sort | Keep existing combat engine. Add a map/cell/goal orchestration layer that delegates to it and handles cooperative progression. |
| Drops | `AddDrop`, `RemoveDrop`, `TrashCan` | `DropManager` and bindings for accepting/rejecting drops | Compare filters, AC protections, temporary-item handling and cleanup. |
| Equipment / class | `EquipClass`, `Equip`, `EquipCached`, `BestGear`, `GetBestItem`, `BankACMisc`, `BankACUnenhancedGear` | `InventoryManager`, `SkillManager`, `EnhancementManager`, `PresetManager` | Preserve class/mode implementation; implement a reliable class/loadout prerequisite workflow. |
| Map / movement | `Join`, `Jump`, `JumpWait`, `GetMapItem`, `GetMapItems`, `CutSceneFixer`, `JoinSWF`, `PvPMove` | `MapManager` has join/ensure/jump/map items, fast travel, private rooms and cutscene handling | Compare map-specific bypasses, public/private room selection, spawn-point behavior and map-load waits. |
| Character / progression | `ChangeAlignment`, `CheckClassRank`, `Rest`, `Relogin`, `FactionRank`, `IsUpholder`, achievement helpers | Player/faction/quest/aura managers cover some state | Audit reputation rank, boosts, class rank, achievement and relogin dependencies. |
| Diagnostics / lifecycle | `Logger`, `FarmingLogger`, `DebugLogger`, `Message`, `RunCore`, `ByPassCheck`, `StopBotEvent`, `CrashDetector`, `ShutdownSkua` | `ApiLogger`, `ScriptManager`, `HScriptEngine`, event dispatcher | Port useful diagnostics and lifecycle behavior; omit desktop-specific prompts or map them to host capabilities. |
| Advanced game workflows | Specialized bosses, PvP, server bypasses, item ghosts, metadata, gear recommendations, dynamic quantity helpers | Some low-level primitives exist; many workflows unverified | Add only after basic parity is stable; use AE_source to verify each game-specific command/state dependency. |

## Initial Haxe facade coverage

The current `CoreBots` namespace now exposes a small additive subset:
- inventory checks: `CheckInventory`, `EnsureItems`, `EnsureAnyItem`, `CheckItem`
- quest helpers: `EnsureLoad`, `EnsureAccept`, `EnsureComplete`, `Quest`, `Complete`, `StoryChainQuest`
- map helpers: `EnsureMap`, `JoinMap`, `Jump`, `GetMapItem`, `MapItem`
- farming helpers: `FarmItem`, `HuntItem`
- gear/lifecycle helpers: `EnsureEquipped`, `EnsureRestored`, `StopCombat`, `StopAutoQuest`

This is a **compatibility starter set**, not feature parity with the 10k-line CoreBots library or the 4k-line CoreFarms / 3.4k-line CoreAdvanced libraries.

### Expanded facade pass

The Haxe CoreBots facade now also delegates these existing primitives, and includes a non-destructive CheckSpaces preflight plus Unbank/ToBank queue wrappers:
- quest flow: CompleteChoose, StoryKillQuest, StoryMapItemQuest, IsQuestComplete, IsQuestAccepted, CanCompleteQuest, IsQuestUnlocked, IsDailyComplete, GetMissingRequirements, AutoQuest
- inventory and storage: GetItemCount, GetTempItems, BankAll, UnbankPreset
- drops and shops: GetDrop, GetDrops, AcceptAllDrops, AcceptAcDrops, BuyItem, BuyItems, SellItem; EnsureLoadAndBuyItem now cooperatively loads the shop, queues one purchase, and waits for an inventory quantity increase with a latched timeout/reset method
- character/map: UseBoost, AutoBoost, EquipLoadout, EnsureHouse, JoinHouse, FastTravel, EnsureMapItem

The bank facade now also has cooperative Swap/EnsureSwap methods and CoreBots.SwapBank. They sequence the two existing transfer queues and report true only after local inventory/bank quantity changes are observed; a 20-second phase timeout is latched to avoid repeated transfers, and CoreBots.ResetSwapBank / Bot.Bank.ResetSwap explicitly clears it before retry. Because this is client-state observation rather than an explicit server acknowledgement, live validation is still required.

These are adapters over existing Haxe managers/bindings; they do not claim the corresponding external CoreBots workflows are fully ported. In particular, multi-tick return semantics and purchase/transfer acknowledgement still need runtime validation.

A parity bug was also corrected: the top-level isQuestComplete(id) binding previously called canComplete(id), which reports turn-in eligibility rather than historical completion. It now delegates to hasBeenCompleted(id). The new CoreBots.IsQuestComplete uses the same completed-state semantics.


## Implementation rules

1. Prefer a Haxe helper that runs one safe step per HScript tick over a direct translation of a blocking C# `while` loop.
2. Return explicit workflow state for new multi-step helpers; where compatibility requires bool, document whether it means complete or pending.
3. Reuse existing managers and current combat behavior; do not create a second combat engine.
4. Before adding each helper, record its prerequisites, game commands, state checks, side effects, retries, timeout, and cleanup.
5. Use [AE_source](https://github.com/JonasAlv/AE_source) when the helper depends on a game-state field or command whose behavior is unclear.
6. Test each helper against a representative script before porting more advanced workflows.
