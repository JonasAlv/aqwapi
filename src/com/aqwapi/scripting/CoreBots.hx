package com.aqwapi.scripting;

import com.aqwapi.Api;

/**
 * Namespaced, CoreBots-style facade for HScript.
 *
 * The first version deliberately delegates to the existing ScriptBindings shortcuts.
 * This avoids creating a second implementation of quest/combat/inventory logic and
 * preserves the current CombatManager/CombatEngine behavior. New multi-tick helpers
 * should be added here only after their state/return/timeout contract is specified.
 *
 * Script examples:
 *   CoreBots.storyChainQuest(1234, "battleon");
 *   CoreBots.farmItem("Training Golem", "Sample Item", 1);
 *   CoreBots.ensureMap("battleon", "Enter", "Spawn");
 *
 * Boolean workflow helpers are cooperative: scripts should call them on successive
 * HScript ticks until they report completion, following the underlying shortcut's
 * existing contract.
 */
class CoreBots {
    private static var _buyWorkflows:Map<String, Dynamic> = new Map<String, Dynamic>();

    private static function invoke(name:String, args:Array<Dynamic>):Dynamic {
        ScriptBindings.ensureInitialized();
        if (!ScriptBindings.hasShortcut(name)) {
            return null;
        }
        var fn:Dynamic = ScriptBindings.getShortcut(name);
        return Reflect.callMethod(null, fn, args);
    }

    private static function asBool(value:Dynamic):Bool {
        return value == true;
    }

    /** Ensures map/cell/pad using the existing map manager behavior. */
    public static function ensureMap(mapName:String, cell:String = null, pad:String = null):Bool {
        return asBool(invoke("ensureMap", [mapName, cell, pad]));
    }

    /** Runs the existing per-tick quest prerequisite helper. */
    public static function quest(questId:Dynamic, mapName:String = null):Bool {
        return asBool(invoke("quest", [questId, mapName]));
    }

    /** Runs the existing multi-tick quest-chain helper. */
    public static function storyChainQuest(questId:Dynamic, mapName:String = null):Bool {
        return asBool(invoke("storyChainQuest", [questId, mapName]));
    }

    /** Collects map items using the existing quantity/map-aware shortcut. */
    public static function mapItem(itemId:Int, arg2:Dynamic = 1, arg3:Dynamic = null, arg4:Dynamic = null):Bool {
        return asBool(invoke("mapItem", [itemId, arg2, arg3, arg4]));
    }

    /** Starts/continues the existing combat-engine item-farming workflow. */
    public static function farmItem(monster:Dynamic, item:String, quantity:Int = 1, isTemp:Bool = false):Bool {
        return asBool(invoke("farmItem", [monster, item, quantity, isTemp]));
    }

    /** Starts/continues the existing hunt-for-item workflow. */
    public static function huntItem(monster:Dynamic, item:Dynamic, quantity:Int = 1, mapName:String = null):Bool {
        return asBool(invoke("huntItem", [monster, item, quantity, mapName]));
    }

    /** Completes a quest through the existing prerequisite/reward-choice path. */
    public static function complete(questId:Dynamic, rewardChoice:Dynamic = null):Bool {
        return asBool(invoke("complete", [questId, rewardChoice]));
    }

    /** Ensures an item is equipped, using the existing equip workflow. */
    public static function ensureEquipped(itemName:Dynamic):Bool {
        return asBool(invoke("ensureEquipped", [itemName]));
    }

    /** Ensures previously stored gear has been restored. */
    public static function ensureRestored():Bool {
        return asBool(invoke("ensureRestored", []));
    }

    /** Checks the existing inventory/quest quantity semantics. */
    public static function hasItem(itemName:Dynamic, quantity:Int = 1):Bool {
        return asBool(invoke("hasItem", [itemName, quantity]));
    }

    /** Ensures quest data is loaded; call on successive ticks until true. */
    public static function ensureQuestsLoaded(questIds:Dynamic):Bool {
        return asBool(invoke("ensureQuestsLoaded", [questIds]));
    }

    /** Stops the existing combat system without replacing its implementation. */
    public static function stopCombat():Void {
        invoke("stopCombat", []);
    }

    /** Stops the existing automatic quest runner. */
    public static function stopAutoQuest():Void {
        invoke("stopAutoQuest", []);
    }
    /** Checks prerequisites across inventory/temp/house/bank and queues bank withdrawals when requested. */
    public static function ensureItems(items:Dynamic, quantity:Int = 1, moveToInventory:Bool = true):Bool {
        return Api.invHelper != null && Api.invHelper.hasAll(items, quantity, moveToInventory);
    }

    /** Checks whether any candidate item is available across the supported containers. */
    public static function ensureAnyItem(items:Dynamic, quantity:Int = 1, moveToInventory:Bool = true):Bool {
        return Api.invHelper != null && Api.invHelper.hasAny(items, quantity, moveToInventory);
    }

    /** Checks one item across containers, optionally queuing a bank withdrawal. */
    public static function checkItem(item:Dynamic, quantity:Int = 1, moveToInventory:Bool = true):Bool {
        return Api.invHelper != null && Api.invHelper.check(item, quantity, moveToInventory);
    }

    public static function EnsureItems(items:Dynamic, quantity:Int = 1, moveToInventory:Bool = true):Bool {
        return ensureItems(items, quantity, moveToInventory);
    }

    public static function EnsureAnyItem(items:Dynamic, quantity:Int = 1, moveToInventory:Bool = true):Bool {
        return ensureAnyItem(items, quantity, moveToInventory);
    }

    public static function CheckItem(item:Dynamic, quantity:Int = 1, moveToInventory:Bool = true):Bool {
        return checkItem(item, quantity, moveToInventory);
    }

    // PascalCase aliases ease porting scripts that use Skua/CoreBots naming.
    public static function EnsureMap(mapName:String, cell:String = null, pad:String = null):Bool {
        return ensureMap(mapName, cell, pad);
    }

    public static function Quest(questId:Dynamic, mapName:String = null):Bool {
        return quest(questId, mapName);
    }

    public static function StoryChainQuest(questId:Dynamic, mapName:String = null):Bool {
        return storyChainQuest(questId, mapName);
    }

    public static function MapItem(itemId:Int, arg2:Dynamic = 1, arg3:Dynamic = null, arg4:Dynamic = null):Bool {
        return mapItem(itemId, arg2, arg3, arg4);
    }

    public static function FarmItem(monster:Dynamic, item:String, quantity:Int = 1, isTemp:Bool = false):Bool {
        return farmItem(monster, item, quantity, isTemp);
    }

    public static function HuntItem(monster:Dynamic, item:Dynamic, quantity:Int = 1, mapName:String = null):Bool {
        return huntItem(monster, item, quantity, mapName);
    }

    public static function Complete(questId:Dynamic, rewardChoice:Dynamic = null):Bool {
        return complete(questId, rewardChoice);
    }

    public static function EnsureEquipped(itemName:Dynamic):Bool {
        return ensureEquipped(itemName);
    }

    public static function EnsureRestored():Bool {
        return ensureRestored();
    }

    public static function HasItem(itemName:Dynamic, quantity:Int = 1):Bool {
        return hasItem(itemName, quantity);
    }

    public static function EnsureQuestsLoaded(questIds:Dynamic):Bool {
        return ensureQuestsLoaded(questIds);
    }

    public static function StopCombat():Void {
        stopCombat();
    }

    public static function StopAutoQuest():Void {
        stopAutoQuest();
    }

    /** CoreBots-compatible inventory prerequisite check for one item or a list of items. */
    public static function checkInventory(items:Dynamic, quantity:Int = 1, any:Bool = false, toInv:Bool = true):Bool {
        if (Api.invHelper == null) return false;
        if (Std.isOfType(items, Array)) {
            return any
                ? Api.invHelper.hasAny(items, quantity, toInv)
                : Api.invHelper.hasAll(items, quantity, toInv);
        }
        if (items != null && Std.string(items).indexOf(",") >= 0) {
            return any
                ? Api.invHelper.hasAny(items, quantity, toInv)
                : Api.invHelper.hasAll(items, quantity, toInv);
        }
        return Api.invHelper.check(items, quantity, toInv);
    }


    private static function requirementsAvailable(requirements:Array<Dynamic>):Bool {
        if (requirements == null || requirements.length == 0) return true;
        if (Api.invHelper == null) return false;
        var ready = true;
        for (req in requirements) {
            if (req == null) continue;
            var itemId:Int = req.ItemID != null ? Std.int(req.ItemID) : (req.id != null ? Std.int(req.id) : 0);
            var itemName:String = req.sName != null ? Std.string(req.sName) : (req.name != null ? Std.string(req.name) : "");
            var quantity:Int = req.iQty != null ? Std.int(req.iQty) : (req.qty != null ? Std.int(req.qty) : 1);
            var lookup:Dynamic = itemId > 0 ? itemId : itemName;
            if (lookup == null || Std.string(lookup) == "") continue;
            if (!Api.invHelper.check(lookup, quantity, true)) ready = false;
        }
        return ready;
    }

    /** Selects an unowned choice reward and queues completion using QuestManager's existing logic. */
    public static function ensureCompleteChoose(questId:Dynamic, preferredItems:Dynamic = null):Bool {
        if (Api.quest == null) return false;
        var id = Api.quest.resolveQuestId(questId);
        if (id <= 0) return false;
        var questData = Api.quest.get(id);
        if (questData != null && questData.once && Api.quest.hasBeenCompleted(id)) return true;
        if (!Api.quest.isLoaded(id)) {
            Api.quest.load(id);
            return false;
        }
        if (!Api.quest.isInProgress(id)) {
            ensureAccept(id);
            return false;
        }
        if (!requirementsAvailable(Api.quest.getRequirements(id))) return false;
        if (!requirementsAvailable(Api.quest.getAcceptRequirements(id))) return false;
        return Api.quest.ensureCompleteChoose(id, preferredItems);
    }

    /** Starts completion for all accepted quests in the supplied scalar or array. */
    public static function completeMultiple(questIds:Dynamic):Void {
        if (Api.quest != null) Api.quest.completeMultiple(questIds);
    }

    public static function EnsureCompleteChoose(questId:Dynamic, preferredItems:Dynamic = null):Bool {
        return ensureCompleteChoose(questId, preferredItems);
    }

    public static function CompleteMultiple(questIds:Dynamic):Void {
        completeMultiple(questIds);
    }

    /** Loads quest data if necessary and starts acceptance; call again until true. */
    public static function ensureAccept(questId:Dynamic):Bool {
        if (Api.quest == null) return false;
        var id = Api.quest.resolveQuestId(questId);
        if (id <= 0) return false;
        var questData = Api.quest.get(id);
        if (questData != null && questData.once && Api.quest.hasBeenCompleted(id)) return true;
        if (Api.quest.isInProgress(id)) return true;
        if (!Api.quest.isLoaded(id)) {
            Api.quest.load(id);
            return false;
        }
        Api.quest.ensureAccept(id);
        return Api.quest.isInProgress(id);
    }

    /** Completes a loaded/accepted quest when requirements are ready; call again until true. */
    public static function ensureComplete(questId:Dynamic, itemId:Dynamic = -1):Bool {
        if (Api.quest == null) return false;
        var id = Api.quest.resolveQuestId(questId);
        if (id <= 0) return false;
        var questData = Api.quest.get(id);
        if (questData != null && questData.once && Api.quest.hasBeenCompleted(id)) return true;
        if (!Api.quest.isLoaded(id)) {
            Api.quest.load(id);
            return false;
        }
        if (!Api.quest.isInProgress(id)) {
            ensureAccept(id);
            return false;
        }
        // Match CoreBots prerequisites: banked turn-in/accept items must be available before completing.
        if (!requirementsAvailable(Api.quest.getRequirements(id))) return false;
        if (!requirementsAvailable(Api.quest.getAcceptRequirements(id))) return false;
        if (!Api.quest.canComplete(id)) return false;
        return asBool(invoke("complete", [id, itemId]));
    }

    /** Ensures quest data is loaded; call again until true. */
    public static function ensureLoad(questId:Dynamic):Bool {
        if (Api.quest == null) return false;
        var id = Api.quest.resolveQuestId(questId);
        if (id <= 0) return false;
        if (Api.quest.isLoaded(id)) return true;
        Api.quest.load(id);
        return false;
    }

    /** Collects a map item with quantity/map prerequisites using the existing stateful shortcut. */
    public static function getMapItem(itemId:Int, quantity:Int = 1, mapName:String = null):Bool {
        return asBool(invoke("mapItem", [itemId, quantity, mapName]));
    }

    /** Cooperative map join helper; returns true once map/cell/pad are ready. */
    public static function joinMap(mapName:String, cell:String = "Enter", pad:String = "Spawn"):Bool {
        return ensureMap(mapName, cell, pad);
    }

    /** Cooperative cell jump helper; returns true once the requested cell/pad is ready. */
    public static function jump(cell:String = "Enter", pad:String = "Spawn", ignoreCheck:Bool = false):Bool {
        if (Api.map == null) return false;
        if (ignoreCheck) {
            Api.map.jump(cell, pad, true);
            return Api.map.isCell(cell);
        }
        return Api.map.ensureCell(cell, pad);
    }

    /** CoreBots-style cooperative Join; publicRoom temporarily disables private-room routing for this join. */
    public static function join(mapName:String, cell:String = "Enter", pad:String = "Spawn", publicRoom:Bool = false, ignoreCheck:Bool = false):Bool {
        if (Api.map == null || mapName == null || StringTools.trim(mapName) == "") return false;
        if (!Api.map.isMap(mapName) || ignoreCheck) {
            var previousPrivateRoom = Api.map.usePrivateRoom;
            if (publicRoom) Api.map.usePrivateRoom = false;
            Api.map.join(mapName, cell, pad, ignoreCheck);
            Api.map.usePrivateRoom = previousPrivateRoom;
            return false;
        }
        return Api.map.ensure(mapName, cell, pad);
    }

    public static function CheckInventory(items:Dynamic, quantity:Int = 1, any:Bool = false, toInv:Bool = true):Bool {
        return checkInventory(items, quantity, any, toInv);
    }

    public static function EnsureAccept(questId:Dynamic):Bool {
        return ensureAccept(questId);
    }

    public static function EnsureComplete(questId:Dynamic, itemId:Dynamic = -1):Bool {
        return ensureComplete(questId, itemId);
    }

    public static function EnsureLoad(questId:Dynamic):Bool {
        return ensureLoad(questId);
    }

    public static function GetMapItem(itemId:Int, quantity:Int = 1, mapName:String = null):Bool {
        return getMapItem(itemId, quantity, mapName);
    }

    public static function JoinMap(mapName:String, cell:String = "Enter", pad:String = "Spawn"):Bool {
        return joinMap(mapName, cell, pad);
    }

    public static function Jump(cell:String = "Enter", pad:String = "Spawn", ignoreCheck:Bool = false):Bool {
        return jump(cell, pad, ignoreCheck);
    }

    public static function Join(mapName:String, cell:String = "Enter", pad:String = "Spawn", publicRoom:Bool = false, ignoreCheck:Bool = false):Bool {
        return join(mapName, cell, pad, publicRoom, ignoreCheck);
    }

    /**
     * Cooperative equivalent of CoreBots.KillMonster.
     * Ensures the requested map/cell first, then delegates all targeting and combat
     * to the existing CombatManager/CombatEngine. Call from onTick until item goals
     * are met; without an item goal, combat continues until stopped by the script.
     */
    public static function killMonster(mapName:String, cell:String, pad:String, monster:Dynamic, item:Dynamic = null, quantity:Int = 1, isTemp:Bool = true):Bool {
        if (Api.map == null || !Api.map.ensure(mapName, cell, pad)) return false;
        if (item != null && StringTools.trim(Std.string(item)) != "") {
            return Api.combat != null && Api.combat.farmItem(monster, Std.string(item), quantity, isTemp);
        }
        return Api.combat != null && Api.combat.hunt(monster, 1);
    }

    /** Cooperative equivalent of CoreBots.HuntMonster, preserving the current combat engine. */
    public static function huntMonster(mapName:String, monster:Dynamic, item:Dynamic = null, quantity:Int = 1, isTemp:Bool = true):Bool {
        if (Api.map == null || !Api.map.ensure(mapName)) return false;
        if (item != null && StringTools.trim(Std.string(item)) != "") {
            return Api.combat != null && Api.combat.farmItem(monster, Std.string(item), quantity, isTemp);
        }
        return Api.combat != null && Api.combat.hunt(monster);
    }

    /** Uses the existing quest-aware hunt workflow. */
    public static function huntMonsterQuest(questId:Dynamic, monsterName:String = null):Bool {
        if (Api.quest == null || Api.combat == null) return false;
        var id = Api.quest.resolveQuestId(questId);
        return id > 0 && Api.combat.huntQuest(id, monsterName);
    }

    public static function KillMonster(mapName:String, cell:String, pad:String, monster:Dynamic, item:Dynamic = null, quantity:Int = 1, isTemp:Bool = true):Bool {
        return killMonster(mapName, cell, pad, monster, item, quantity, isTemp);
    }

    public static function HuntMonster(mapName:String, monster:Dynamic, item:Dynamic = null, quantity:Int = 1, isTemp:Bool = true):Bool {
        return huntMonster(mapName, monster, item, quantity, isTemp);
    }

    public static function HuntMonsterQuest(questId:Dynamic, monsterName:String = null):Bool {
        return huntMonsterQuest(questId, monsterName);
    }


    // ---------------------------------------------------------------------
    // Additional wrappers over existing ScriptBindings.
    // These intentionally delegate instead of duplicating game/combat logic.
    // Boolean workflow helpers are cooperative: call again on later ticks
    // until the goal is met. Void actions only enqueue/start the operation.
    // ---------------------------------------------------------------------

    public static function ensureMapItem(itemId:Int, arg2:Dynamic = 1, arg3:Dynamic = null, arg4:Dynamic = null):Bool {
        return asBool(invoke("ensureMapItem", [itemId, arg2, arg3, arg4]));
    }

    public static function completeChoose(questId:Dynamic, preferredItems:Dynamic = null):Bool {
        return asBool(invoke("completeChoose", [questId, preferredItems]));
    }

    public static function storyKillQuest(questId:Dynamic, mapName:String, monster:Dynamic):Bool {
        return asBool(invoke("storyKillQuest", [questId, mapName, monster]));
    }

    public static function storyMapItemQuest(questId:Dynamic, mapName:String, itemIds:Dynamic, amount:Int = 1):Bool {
        return asBool(invoke("storyMapItemQuest", [questId, mapName, itemIds, amount]));
    }

    public static function autoQuest(quests:Dynamic):Void {
        invoke("autoQuest", [quests]);
    }

    public static function isAutoQuestRunning():Bool {
        return asBool(invoke("isAutoQuestRunning", []));
    }

    public static function isQuestComplete(questId:Dynamic):Bool {
        return Api.quest != null && Api.quest.hasBeenCompleted(questId);
    }

    public static function isQuestAccepted(questId:Dynamic):Bool {
        return asBool(invoke("isQuestAccepted", [questId]));
    }

    public static function canCompleteQuest(questId:Dynamic):Bool {
        return asBool(invoke("canComplete", [questId]));
    }

    public static function isQuestUnlocked(questId:Dynamic):Bool {
        return asBool(invoke("isQuestUnlocked", [questId]));
    }

    public static function isDailyComplete(questId:Dynamic):Bool {
        return asBool(invoke("isDailyComplete", [questId]));
    }

    public static function getMissingRequirements(questId:Dynamic):Array<Dynamic> {
        var result:Dynamic = invoke("getMissingRequirements", [questId]);
        return result != null ? cast result : [];
    }

    public static function getItemCount(item:Dynamic):Int {
        var result:Dynamic = invoke("getItemCount", [item]);
        return result != null ? Std.int(result) : 0;
    }

    public static function getTempItems():Array<Dynamic> {
        var result:Dynamic = invoke("getTempItems", []);
        return result != null ? cast result : [];
    }

    public static function getDrop(item:Dynamic):Void {
        invoke("getDrop", [item]);
    }

    public static function getDrops(items:Dynamic = "all"):Void {
        invoke("getDrops", [items]);
    }

    public static function acceptAllDrops(enabled:Bool = true):Void {
        invoke("acceptAllDrops", [enabled]);
    }

    public static function acceptAcDrops(enabled:Bool = true):Void {
        invoke("acceptAcDrops", [enabled]);
    }

    public static function buyItem(shopId:Dynamic, itemNameOrId:Dynamic = null, quantity:Int = 1):Void {
        invoke("buyItem", [shopId, itemNameOrId, quantity]);
    }

    public static function buyItems(items:Array<Dynamic>, gapMs:Int = 1000):Int {
        var result:Dynamic = invoke("buyItems", [items, gapMs]);
        return result != null ? Std.int(result) : 0;
    }

    public static function sellItem(itemNameOrId:Dynamic, quantity:Int = 1):Void {
        invoke("sellItem", [itemNameOrId, quantity]);
    }

    public static function bankAll(exclude:Dynamic = null):Void {
        invoke("bankAll", [exclude]);
    }

    public static function unbankPreset(presetName:String):Void {
        invoke("unbankPreset", [presetName]);
    }

    public static function useBoost(nameOrId:Dynamic):Bool {
        return asBool(invoke("useBoost", [nameOrId]));
    }

    public static function autoBoost(boostType:String, enabled:Bool = true):Void {
        invoke("autoBoost", [boostType, enabled]);
    }

    public static function smartEnhance(className:Dynamic = null, force:Dynamic = null):Void {
        invoke("smartEnhance", [className, force]);
    }

    public static function equipLoadout(loadout:String):Bool {
        return asBool(invoke("equipLoadout", [loadout]));
    }

    public static function ensureHouse():Bool {
        return asBool(invoke("ensureHouse", []));
    }

    public static function joinHouse(username:String = ""):Void {
        invoke("joinHouse", [username]);
    }

    public static function fastTravel(destination:String):Bool {
        return asBool(invoke("fastTravel", [destination]));
    }


    /**
     * Checks whether the current inventory has enough free slots for items not
     * already owned in inventory, temporary inventory, house storage, or bank.
     * This is a non-destructive preflight: it does not bank gear or start transfers.
     */
    public static function checkSpaces(items:Dynamic):Bool {
        if (Api.inventory == null || Api.invHelper == null) return false;
        var list:Array<Dynamic> = [];
        if (items == null) return true;
        if (Std.isOfType(items, Array)) {
            list = cast items;
        } else {
            var raw = StringTools.trim(Std.string(items));
            if (raw == "") return true;
            if (raw.indexOf(",") >= 0) {
                for (part in raw.split(",")) {
                    var item = StringTools.trim(part);
                    if (item != "") list.push(item);
                }
            } else {
                list.push(items);
            }
        }

        var requiredSlots = 0;
        for (item in list) {
            if (item == null || StringTools.trim(Std.string(item)) == "") continue;
            if (!Api.invHelper.check(item, 1, false)) requiredSlots++;
        }
        return Api.inventory.freeSlots >= requiredSlots;
    }

    /** Cooperative swap between an inventory item and a bank item. Call until true. */
    public static function swapBank(invItem:Dynamic, bankItem:Dynamic, loadBank:Bool = true):Bool {
        return Api.bank != null && Api.bank.EnsureSwap(invItem, bankItem, loadBank);
    }

    public static function SwapBank(invItem:Dynamic, bankItem:Dynamic, loadBank:Bool = true):Bool {
        return swapBank(invItem, bankItem, loadBank);
    }

    public static function resetSwapBank(invItem:Dynamic, bankItem:Dynamic):Void {
        if (Api.bank != null) Api.bank.ResetSwap(invItem, bankItem);
    }

    public static function ResetSwapBank(invItem:Dynamic, bankItem:Dynamic):Void {
        resetSwapBank(invItem, bankItem);
    }

    /** Starts bank-to-inventory transfers through the existing queue. */
    public static function unbank(items:Dynamic):Void {
        if (Api.inventory != null) Api.inventory.ensureUnbanked(items);
    }

    /** Queues inventory-to-bank transfers through the existing manager. */
    public static function toBank(items:Dynamic):Void {
        if (Api.inventory != null) Api.inventory.bank(items);
    }

    public static function CheckSpaces(items:Dynamic):Bool {
        return checkSpaces(items);
    }

    public static function Unbank(items:Dynamic):Void {
        unbank(items);
    }

    public static function ToBank(items:Dynamic):Void {
        toBank(items);
    }


    /**
     * Cooperative equivalent of Skua EnsureLoadAndBuyItem.
     * Call on successive ticks until true. It loads the requested shop, queues one
     * purchase, then waits for the requested inventory quantity increase. A timed-out
     * workflow is latched as failed to prevent duplicate purchases on every script tick;
     * call resetLoadAndBuyItem before intentionally retrying.
     */
    public static function ensureLoadAndBuyItem(shopId:Int, item:Dynamic, quantity:Int = 1, timeoutMs:Int = 30000):Bool {
        if (Api.shop == null || Api.inventory == null || shopId <= 0 || item == null || quantity <= 0) return false;
        var itemKey = StringTools.trim(Std.string(item));
        if (itemKey == "") return false;
        var key = Std.string(shopId) + "|" + itemKey.toLowerCase() + "|" + Std.string(quantity);
        var now = com.aqwapi.utils.ApiTime.now();
        var state:Dynamic = _buyWorkflows.get(key);
        if (state == null) {
            state = {
                phase: "load",
                startedAt: now,
                phaseStartedAt: now,
                baselineQuantity: Api.inventory.getQuantity(itemKey),
                loadRequested: false,
                buyRequested: false
            };
            _buyWorkflows.set(key, state);
        }

        if (state.phase == "failed") return false;
        if (Api.inventory.getQuantity(itemKey) >= state.baselineQuantity + quantity) {
            _buyWorkflows.remove(key);
            return true;
        }
        if (now - state.startedAt >= timeoutMs) {
            state.phase = "failed";
            return false;
        }

        if (state.phase == "load") {
            if (Api.shop.IsLoaded && Api.shop.ID == shopId) {
                state.phase = "buy";
                state.phaseStartedAt = now;
            } else if (!state.loadRequested) {
                Api.shop.loadShop(shopId);
                state.loadRequested = true;
                return false;
            } else {
                return false;
            }
        }

        if (state.phase == "buy" && !state.buyRequested) {
            Api.shop.buyItem(itemKey, quantity);
            state.buyRequested = true;
            state.phase = "await-item";
            state.phaseStartedAt = now;
            return false;
        }

        return state.phase == "await-item" && Api.inventory.getQuantity(itemKey) >= state.baselineQuantity + quantity;
    }

    public static function resetLoadAndBuyItem(shopId:Int, item:Dynamic, quantity:Int = 1):Void {
        if (item == null) return;
        var key = Std.string(shopId) + "|" + StringTools.trim(Std.string(item)).toLowerCase() + "|" + Std.string(quantity);
        _buyWorkflows.remove(key);
    }

    public static function EnsureLoadAndBuyItem(shopId:Int, item:Dynamic, quantity:Int = 1, timeoutMs:Int = 30000):Bool {
        return ensureLoadAndBuyItem(shopId, item, quantity, timeoutMs);
    }

    public static function ResetLoadAndBuyItem(shopId:Int, item:Dynamic, quantity:Int = 1):Void {
        resetLoadAndBuyItem(shopId, item, quantity);
    }


    // PascalCase aliases for scripts ported from CoreBots/Skua conventions.
    public static function EnsureMapItem(itemId:Int, arg2:Dynamic = 1, arg3:Dynamic = null, arg4:Dynamic = null):Bool {
        return ensureMapItem(itemId, arg2, arg3, arg4);
    }

    public static function CompleteChoose(questId:Dynamic, preferredItems:Dynamic = null):Bool {
        return completeChoose(questId, preferredItems);
    }

    public static function StoryKillQuest(questId:Dynamic, mapName:String, monster:Dynamic):Bool {
        return storyKillQuest(questId, mapName, monster);
    }

    public static function StoryMapItemQuest(questId:Dynamic, mapName:String, itemIds:Dynamic, amount:Int = 1):Bool {
        return storyMapItemQuest(questId, mapName, itemIds, amount);
    }

    public static function IsQuestComplete(questId:Dynamic):Bool {
        return isQuestComplete(questId);
    }

    public static function IsQuestAccepted(questId:Dynamic):Bool {
        return isQuestAccepted(questId);
    }

    public static function CanCompleteQuest(questId:Dynamic):Bool {
        return canCompleteQuest(questId);
    }

    public static function GetMissingRequirements(questId:Dynamic):Array<Dynamic> {
        return getMissingRequirements(questId);
    }

    public static function GetItemCount(item:Dynamic):Int {
        return getItemCount(item);
    }

    public static function BuyItem(shopId:Dynamic, itemNameOrId:Dynamic = null, quantity:Int = 1):Void {
        buyItem(shopId, itemNameOrId, quantity);
    }

    public static function BuyItems(items:Array<Dynamic>, gapMs:Int = 1000):Int {
        return buyItems(items, gapMs);
    }

    public static function SellItem(itemNameOrId:Dynamic, quantity:Int = 1):Void {
        sellItem(itemNameOrId, quantity);
    }

    public static function UseBoost(nameOrId:Dynamic):Bool {
        return useBoost(nameOrId);
    }

    public static function EquipLoadout(loadout:String):Bool {
        return equipLoadout(loadout);
    }

    public static function FastTravel(destination:String):Bool {
        return fastTravel(destination);
    }

}
