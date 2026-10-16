# Detailed Skua interface review (first pass)

Source of truth: public contracts in [VibeSkua](https://github.com/NinjaXz/VibeSkua). This document records concrete members observed during source inspection and maps them to the Haxe implementation. **A related method is not automatically a parity match.** Return semantics, timing, side effects, overloads and edge cases still require review.

## Player — `IScriptPlayer`

Observed properties include `Guild`, `ID`, `XP`, `RequiredXP`, `AccessLevel`, `Cell`, `Pad`, `ServerIP`, `State`, `LoggedIn`, `Playing`, `Username`, `Password`, `Kicked`, `IsMember`, `Health`, `MaxHealth`, `Mana`, `MaxMana`, `Level`, `Gold`, `Coins`, `CurrentClass`, `CurrentClassRank`, `Target`, `HasTarget`, `Loaded`, `Skills`, `Stats`, `AFK`, `X`, `Y`, `Scale`, and `WalkSpeed`.

Observed actions: `Goto(name)`, `SetSpawnPoint()`, `SetSpawnPoint(cell, pad)`, `WalkTo(x, y, speed)`, `Rest(full)`.

**Haxe mapping:** `PlayerManager` exposes HP/MP, level, gold, username, alive/combat state, target, cell and pad. This branch now adds PascalCase aliases for the verified subset (`Health`, `MaxHealth`, `Mana`, `MaxMana`, `Gold`, `Username`, `Level`, `State`, `Cell`, `Pad`, `HasTarget`, `CurrentClass`, `Coins`, `IsMember`, `X`, `Y`) plus `GetAura*`, `HasAura`, `SetSpawnPoint`, and `GetFactionRank`. `ScriptInterp` also resolves implemented manager services under Skua-style names such as `Bot.Player`, `Bot.Map`, `Bot.Quests`, and `Bot.Inventory`, and now falls back from PascalCase member names to existing lower-camel members when reflection finds a match. Current parity remains **partial**: guild/ID/access level/server IP/login state/kicked/AFK/loaded/class rank/skill data/WalkTo/Rest and other members need exact mapping. Do not expose `Password` as a general script-visible field without a specific, safe requirement.

## Map — `IScriptMap`

Observed properties: `LastMap`, `Loading`, `FilePath`, `FileName`, `Name`, `FullName`, `Loaded`, `RoomID`, `PlayerCount`, `Cells`, `PlayerNames`, `Players`, and `CellPlayers`. Observed actions: `Join`, `JoinIgnore`, `JoinPacket`, `Jump`, `Reload`, `GetMapItem`, player lookup helpers, map-item search and cache clearing.

**Haxe mapping:** This branch adds PascalCase aliases for `Loaded`, `Name`, and `RoomID`, plus explicit `Join`, `JoinIgnore`, `Jump`, `GetMapItem`, `IsMap`, `IsCell`, and `Reload` wrappers. The lower-level manager remains authoritative. Parity is **partial**: `JoinPacket`, `Loading`, SWF path/file name, full map name, player collections/lookups and map-item cache semantics still need exact implementation. The `Join` wrapper passes `ignoreCheck` to the existing force parameter; verify map-specific behavior and `autoCorrect` after loading.

## Skill — `IScriptSkill`

Observed members:
- `BaseProvider`, `OverrideProvider`, `SkillTimeout`, `SkillInterval`, `TimerRunning`, `SkillUseMode`.
- `CanUseSkill(index)`, `UseSkill(index)`, `Resume()`, `Pause()`.
- `LoadAdvanced(skills, skillTimeout, skillMode)`, `LoadAdvanced(className, autoEquip, useMode)`, `LoadAdvanced(className, mode, autoEquip)`.
- `StartAdvanced(className, mode, autoEquip)`, `StartAdvanced(skills, skillTimeout, skillMode)`, `StartAdvanced(className, autoEquip, useMode)`, `SetProvider(provider)`, `Start()`, `Stop()`, `UseBaseProvider()`.

**Haxe mapping:** `SkillManager` has extensive class/mode configuration, custom mode storage, combo/timeout settings and class resolution; `CombatManager` uses skill configuration. Exact provider and timer parity is **unverified**. Keep current class/mode engine and add adapters if required.

## Options — `IScriptOption`

Observed mutable settings include `ReloginTryDelay`, `LoginTimeout`, `AcceptACDrops`, `AcceptAllDrops`, `RejectAllDrops`, `AggroAllMonsters`, `AggroMonsters`, `AttackWithoutTarget`, `AutoRelogin`, `AutoReloginAny`, `RetryRelogin`, `CustomGuild`, `CustomName`, `DisableCollisions`, `DisableDeathAds`, `DisableFX`, `MaximumTries`, `ActionDelay`, `GuildColor`, `HidePlayers`, `HuntBuffer`, `HuntDelay`, `InfiniteRange`, `LagKiller`, `HeadlessMode`, `StreamerMode`, `OptimizePlayers`, `UseFunctionBasedSkills`, `LoadTimeout`, `ReloginServer`, `Magnetise`, `NameColor`, `PrivateRooms`, `RestPackets`, `SafeRelogin`, `SafeTimings`, `SetFPS`, `ShowFPS`, `SkipCutscenes`, `WalkSpeed`, `PrivateNumber`, `JoinMapTries`, `QuestAcceptAndCompleteTries`, `ReloginTries`, `HuntPriority`, plus `OptionDictionary`, `Reset()`, `ResetToDefault()`, and `Save()`.

**Haxe mapping:** some equivalent controls exist in `MapManager`, `VisualManager`, `CombatManager`, presets, and script settings. There is no confirmed one-to-one unified `Options` object yet. Prioritize options that affect workflows and script compatibility; host-specific UI options may need an explicit Linux-host decision.

## Timed handlers — `IScriptHandlers`

Observed contract: `CurrentHandlers`, `RegisterHandler(ticks, Func<Bot,bool>, name)`, `RegisterHandler(ticks, Action<Bot>, name)`, `RegisterOnce(ticks, Action<Bot>, name)`, `Remove(name/handler/list)`, `Clear()`. A tick is 20ms. A bool-returning handler is removed when it returns false; the Action overload continues; RegisterOnce removes itself after invocation.

**Haxe mapping:** a first-pass cooperative implementation now exists in `ScriptHandlers.hx` and is ticked by `HScriptEngine`. It supports recurring/one-shot registration, remove/clear, PascalCase aliases, and lifecycle cleanup. **Partial pending compile/runtime tests:** the HScript host wakes every 100ms by default, so it cannot match 20ms cadence exactly; list-based removal and all overload shapes are not fully equivalent.

## Send — `IScriptSend`

Observed methods: `Packet(packet, type)`, `ClientPacket(packet, type)`, client event/guild/moderator/server/warning/whisper/zone messages, `Whisper(name, message)`, and asynchronous packet-spam methods.

**Haxe mapping:** a `sendPacket` shortcut and direct SmartFox transport access exist. This is only **partial**: message routing, encodings, and cancellable spam APIs need comparison against the actual transport layer. Avoid exposing transport operations as successful if the client has not acknowledged them.

## Shop — `IScriptShop`

Observed properties: `IsLoaded`, `ID`, `Items`, `LoadedCache`, `Name`, `ProtectFavorites`. Observed methods: `GetUnmetPurchaseRequirements`, `BuyItem(name/id)`, `LoadAndBuyItem(shopId, name/id)`, `EnsureLoadAndBuyItem(shopId, name/id)`, `Load(id)`, `LoadArmourCustomizer()`, `LoadHairShop(id)`, `SellItem(name/id)`.

**Haxe mapping:** this branch adds PascalCase `IsLoaded`, `ID`, `Items`, and `Name` properties plus `Load`, `BuyItem`, and `SellItem` aliases over the existing manager. Shop loading, queued buying, loaded-shop state, unmet purchase requirements and favorite protection are already present. The compound `LoadAndBuy` / `EnsureLoadAndBuy` workflows, `LoadedCache`, specialized hair/armor shop loading and result-wait semantics still need exact comparison.

## Monsters — `IScriptMonster`

Observed properties: `CurrentMonsters`, `MapMonsters`, `CurrentAvailableMonsters`. Observed methods: `Exists(name/id)`, `GetCellMonsters()`, `GetLivingMonsterCells(name/id)`, `GetLivingMonsterDataLeafCells(name/id)`, `GetMonsterCells(name/id)`, `GetMonstersByCell(cell)`, `TryGetMonster(name/id)`.

**Haxe mapping:** `MonsterManager` has find-by-name/map-ID, living cells, monster cells, per-cell queries, sorting by HP/distance, best-target selection and on-screen/all-monster queries. Data-leaf-specific cell semantics and DTO field parity remain **partial/unverified**.

## Kill and Hunt — `IScriptKill` / `IScriptHunt`

Observed overload families: monster by name/ID/object, optional cancellation token, `ForItem`, `ForItems`, and `WithPriority` by name/ID/object. Kill also supports player targets.

**Haxe mapping:** `CombatManager` already implements hunt, kill, farm-item, hunt-for-item, hunt-quest, target priorities, combat cancellation and loadout helpers. Keep this system. Map overloads onto it and add cancellation/result semantics without replacing its algorithm.

## Inventory helper — `ScriptInventoryHelper`

The concrete Skua implementation exposes `Check(name/id, quantity, moveToInventory)`, `HasAll(names/IDs, quantity, moveToInventory)`, and `HasAny(names/IDs, quantity, moveToInventory)`. Its implementation inspects bank, inventory, temp inventory and house inventory, optionally moving a needed item into the active inventory.

**Haxe mapping:** `InventoryManager` resolves item location (`temp`, `inventory`, `house`, `bank`), counts items across multiple game structures, and has bank/unbank queues and capacity checks. This branch adds PascalCase `MiscSlots`, `MiscUsedSlots`, and `MiscFreeSlots` properties; other lower-camel methods such as `GetPool`, `HasSpaceFor`, `CanBank`, and `IsFavorited` can be reached through the guarded PascalCase fallback. A first-pass `InventoryHelper` exposes `Check` / `HasAll` / `HasAny` through `Bot.InvHelper` and `invHelper`. It queues bank withdrawals through existing code and waits for normal inventory quantity before `Check` reports success; house items count as an available prerequisite but are not moved. This branch now exposes separate first-pass `Bot.Bank`, `Bot.TempInv`, and `Bot.House` facades for container-specific item lists, quantities, and presence checks. `Bot.Bank.Load` starts asynchronous loading but does not block; use `Bot.Wait.ForBankLoad()` on later ticks. Swap operations, full inherited item-container contracts, house-transfer workflows, and exact `IsEquipped` semantics remain **partial** pending runtime verification. The legacy lowercase `bank` binding remains mapped to `Api.inventory` for backward compatibility.

## Validation state

- Source inventory is based on interface and implementation files from VibeSkua plus Haxe manager and binding source.
- The new CoreBots facade delegates to existing shortcuts; it does not yet reproduce the external CoreBots/CoreFarms/CoreAdvanced libraries.
- No Haxe compiler is available in the current execution environment and repository cloning failed due unavailable network resolution. New Haxe code is therefore **not compile-tested here**.
- The branch is intentionally separate from `main`; keep it that way.
