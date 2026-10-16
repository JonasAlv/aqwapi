package com.aqwapi.scripting;

import com.aqwapi.Api;
import com.aqwapi.utils.ApiLogger;
import com.aqwapi.utils.ApiTime;

/**
 * Cooperative wait helpers for timer-driven HScript.
 *
 * Unlike Skua's C# Wait helpers, these methods do not block/suspend the current
 * call stack. Call them on successive onTick callbacks and continue only when true.
 */
class ScriptWait {
    private var _states:Map<String, Dynamic> = new Map<String, Dynamic>();
    private var _lastSeenBuyRequestId:Int = 0;
    private var _lastSeenSellRequestId:Int = 0;
    private var _activeBuyRequestId:Int = 0;
    private var _activeSellRequestId:Int = 0;
    private var _activeBuyBaseline:String = "";
    private var _activeSellBaseline:String = "";

    public var lastStatus(default, null):String = "idle";
    public var defaultTimeoutMs:Float = 10000;
    public var WAIT_SLEEP:Int = 100;
    public var OverrideTimeout:Bool = false;
    public var PlayerActionTimeout:Int = 15;
    public var MonsterActionTimeout:Int = 15;
    public var MapActionTimeout:Int = 25;
    public var DropActionTimeout:Int = 10;
    public var ItemActionTimeout:Int = 14;
    public var QuestActionTimeout:Int = 14;
    public var GameActionTimeout:Int = 40;

    private function ticksToMs(ticks:Int, sleepOverride:Int = -1):Float {
        if (ticks <= 0) return 0;
        var interval = sleepOverride < 0 ? WAIT_SLEEP : sleepOverride;
        return ticks * interval;
    }

    public function new() {}

    public function reset(key:String):Void {
        if (key == null) return;
        _states.remove(key);
        _states.remove("true:" + key);
        _states.remove("map:" + key.toLowerCase());
        _states.remove("cell:" + key.toLowerCase());
    }

    public function clear():Void {
        _states = new Map<String, Dynamic>();
        // Ignore requests issued before this script's wait state was reset.
        _lastSeenBuyRequestId = Api.shop != null ? Api.shop.lastBuyRequestId : 0;
        _lastSeenSellRequestId = Api.shop != null ? Api.shop.lastSellRequestId : 0;
        _activeBuyRequestId = 0;
        _activeSellRequestId = 0;
        _activeBuyBaseline = "";
        _activeSellBaseline = "";
        lastStatus = "idle";
    }

    private function poll(key:String, ready:Bool, timeoutMs:Float):Bool {
        if (ready) {
            _states.remove(key);
            lastStatus = "done";
            return true;
        }
        var now = ApiTime.now();
        var state:Dynamic = _states.get(key);
        if (state == null) {
            state = { startedAt: now, timeoutMs: timeoutMs, timedOut: false };
            _states.set(key, state);
        }
        if (state.timedOut == true) {
            lastStatus = "timeout";
            return false;
        }
        var limit:Float = (state.timeoutMs != null) ? state.timeoutMs : timeoutMs;
        if (limit > 0 && now - state.startedAt >= limit) {
            state.timedOut = true;
            lastStatus = "timeout";
            ApiLogger.warn("Wait", "Timed out waiting for " + key + " after " + Std.string(limit) + "ms.");
            return false;
        }
        lastStatus = "pending";
        return false;
    }

    /** Cooperative equivalent of Wait.ForTrue. key must be stable across ticks. */
    public function forTrue(key:String, predicate:Dynamic, timeoutMs:Float = -1):Bool {
        if (key == null || key == "") return false;
        var ready = false;
        if (predicate != null && Reflect.isFunction(predicate)) {
            try {
                ready = Reflect.callMethod(null, predicate, []) == true;
            } catch (e:Dynamic) {
                ApiLogger.error("Wait", "Predicate failed for " + key + ": " + Std.string(e));
                return poll("true:" + key, false, 1);
            }
        }
        var timeout = timeoutMs < 0 ? defaultTimeoutMs : timeoutMs;
        return poll("true:" + key, ready, timeout);
    }

    public function ForTrue(predicate:Dynamic, timeout:Int = 10, sleepOverride:Int = -1, key:String = "default"):Bool {
        return forTrue(key, predicate, ticksToMs(timeout, sleepOverride));
    }

    public function forMapLoad(mapName:String, timeoutMs:Float = -1):Bool {
        var ready = Api.map != null && Api.map.isLoaded && (mapName == null || mapName == "" || Api.map.isMap(mapName));
        return poll("map:" + (mapName == null ? "" : mapName.toLowerCase()), ready, timeoutMs < 0 ? defaultTimeoutMs : timeoutMs);
    }

    public function ForMapLoad(mapName:String, timeout:Int = 20):Bool {
        var effective = OverrideTimeout ? MapActionTimeout : timeout;
        return forMapLoad(mapName, ticksToMs(effective));
    }

    public function forCellChange(cell:String, timeoutMs:Float = -1):Bool {
        var ready = Api.player != null && Api.player.cell != null && cell != null && Api.player.cell.toLowerCase() == cell.toLowerCase();
        return poll("cell:" + (cell == null ? "" : cell.toLowerCase()), ready, timeoutMs < 0 ? defaultTimeoutMs : timeoutMs);
    }

    public function ForCellChange(cell:String, timeout:Int = -1):Bool {
        var effective = timeout < 0 ? (OverrideTimeout ? MapActionTimeout : Std.int(WAIT_SLEEP / 4)) : timeout;
        return forCellChange(cell, ticksToMs(effective));
    }

    public function forCombatExit(timeoutMs:Float = -1):Bool {
        var ready = (Api.player == null || !Api.player.isInCombat) && (Api.combat == null || !Api.combat.isRunning());
        return poll("combat-exit", ready, timeoutMs < 0 ? defaultTimeoutMs : timeoutMs);
    }

    public function ForPlayerPosition(x:Int, y:Int, timeout:Int = 10):Bool {
        var ready = Api.player == null || (Std.int(Api.player.x) == x && Std.int(Api.player.y) == y);
        var effective = OverrideTimeout ? PlayerActionTimeout : timeout;
        return poll("player-position:" + x + ":" + y, ready, ticksToMs(effective));
    }

    public function ForCombatExit(timeout:Int = 10):Bool {
        var effective = OverrideTimeout ? PlayerActionTimeout : timeout;
        return forCombatExit(ticksToMs(effective));
    }

    public function forQuestAccept(questId:Dynamic, timeoutMs:Float = -1):Bool {
        var id = Api.quest != null ? Api.quest.resolveQuestId(questId) : 0;
        if (id <= 0) { lastStatus = "pending"; return false; }
        var ready = Api.quest.isInProgress(id);
        return poll("quest-accept:" + Std.string(id), ready, timeoutMs < 0 ? defaultTimeoutMs : timeoutMs);
    }

    public function ForQuestAccept(questId:Dynamic, timeout:Int = 14):Bool {
        var effective = OverrideTimeout ? QuestActionTimeout : timeout;
        return forQuestAccept(questId, ticksToMs(effective, Std.int(WAIT_SLEEP / 2)));
    }

    public function ForQuestComplete(questId:Dynamic, timeout:Int = 10):Bool {
        var id = Api.quest != null ? Api.quest.resolveQuestId(questId) : 0;
        if (id <= 0) { lastStatus = "pending"; return false; }
        var effective = OverrideTimeout ? QuestActionTimeout : timeout;
        var ready = !Api.quest.isInProgress(id);
        return poll("quest-complete:" + Std.string(id), ready, ticksToMs(effective, Std.int(WAIT_SLEEP / 2)));
    }

    public function ForQuestLoad(questId:Dynamic, timeout:Int = 20):Bool {
        var id = Api.quest != null ? Api.quest.resolveQuestId(questId) : 0;
        if (id <= 0) { lastStatus = "pending"; return false; }
        return poll("quest-load:" + Std.string(id), Api.quest.isLoaded(id), ticksToMs(timeout));
    }

    public function forItemEquip(itemNameOrId:Dynamic, timeoutMs:Float = -1):Bool {
        var ready = Api.inventory != null && Api.inventory.isEquipped(itemNameOrId);
        return poll("equip:" + Std.string(itemNameOrId), ready, timeoutMs < 0 ? defaultTimeoutMs : timeoutMs);
    }

    public function ForFullyRested(timeout:Int = -1):Bool {
        var ready = Api.player == null || (Api.player.hp >= Api.player.maxHp && Api.player.mp >= Api.player.maxMp);
        var effective = timeout < 0 ? 0 : timeout;
        return poll("fully-rested", ready, ticksToMs(effective));
    }

    public function ForMonsterSpawn(nameOrId:Dynamic, timeout:Int = 10):Bool {
        var found = false;
        if (Api.monster != null && nameOrId != null) {
            if (Std.isOfType(nameOrId, Int) || Std.isOfType(nameOrId, Float)) {
                var idText = Std.string(nameOrId);
                for (monster in Api.monster.getAllMonsters()) {
                    if (monster != null && monster.alive && (monster.id == idText || monster.mapId == idText || monster.monsterId == idText)) {
                        found = true;
                        break;
                    }
                }
            } else {
                found = Api.monster.findByName(Std.string(nameOrId), true) != null;
            }
        }
        var effective = OverrideTimeout ? MonsterActionTimeout : timeout;
        return poll("monster-spawn:" + Std.string(nameOrId), found, ticksToMs(effective));
    }

    public function ForMonsterDeath(timeout:Int = -1):Bool {
        // Skua's contract is "no target selected". If the selected target has died,
        // clear that dead target so the wait can finish; never cancel a living target.
        var target = Api.player != null ? Api.player.target : null;
        if (target != null && target.hp <= 0 && Api.combat != null) {
            Api.combat.cancelTarget();
        }
        var ready = Api.game == null || Api.game.world == null || Api.player == null || !Api.player.hasTarget;
        return poll("monster-death", ready, ticksToMs(timeout));
    }

    private function dropExists(item:Dynamic):Bool {
        if (Api.drop == null || item == null) return false;
        var targetId = Std.parseInt(Std.string(item));
        var byId = targetId != null && targetId > 0;
        var targetName = Std.string(item).toLowerCase();
        for (drop in Api.drop.pendingDrops) {
            if (drop == null) continue;
            var id = drop.ItemID != null ? Std.int(drop.ItemID) : (drop.id != null ? Std.int(drop.id) : 0);
            var name = drop.sName != null ? Std.string(drop.sName) : (drop.name != null ? Std.string(drop.name) : "");
            if (byId ? id == targetId : name.toLowerCase() == targetName) return true;
        }
        return false;
    }

    public function ForDrop(item:Dynamic, timeout:Int = 10):Bool {
        var effective = OverrideTimeout ? DropActionTimeout : timeout;
        if (Api.drop != null) Api.drop.scanScreenDrops();
        return poll("drop:" + Std.string(item), dropExists(item), ticksToMs(effective));
    }

    public function ForPickup(item:Dynamic, timeout:Int = 10):Bool {
        var effective = OverrideTimeout ? DropActionTimeout : timeout;
        // Skua waits for the drop to disappear, not for the inventory to contain an
        // item with the same name (which may already be owned before this drop spawns).
        if (Api.drop != null) Api.drop.scanScreenDrops();
        var ready = Api.game == null || Api.game.world == null || !dropExists(item);
        return poll("pickup:" + Std.string(item), ready, ticksToMs(effective));
    }

    /**
     * Waits cooperatively for a buy request to produce an observable inventory change.
     * The ShopManager records the inventory before sending, so a fast response that arrives
     * before the first wait poll is still detected. This is a best-effort local signal, not
     * server acknowledgement: unrelated inventory changes can also satisfy it.
     */
    public function ForItemBuy(timeout:Int = 10):Bool {
        var effective = OverrideTimeout ? ItemActionTimeout : timeout;
        if (Api.shop == null) return poll("item-buy:no-shop", false, ticksToMs(effective));
        var requestId = Api.shop.lastBuyRequestId;
        if (requestId <= _lastSeenBuyRequestId) {
            return poll("item-buy:no-new-request", false, ticksToMs(effective));
        }
        if (requestId != _activeBuyRequestId) {
            if (_activeBuyRequestId > 0) _states.remove("item-buy:" + Std.string(_activeBuyRequestId));
            _activeBuyRequestId = requestId;
            _activeBuyBaseline = Api.shop.lastBuyInventoryBefore;
        }
        var key = "item-buy:" + Std.string(_activeBuyRequestId);
        var ready = Api.shop.getInventorySignature() != _activeBuyBaseline;
        var result = poll(key, ready, ticksToMs(effective));
        if (result || lastStatus == "timeout") {
            _lastSeenBuyRequestId = _activeBuyRequestId;
            _activeBuyRequestId = 0;
            _activeBuyBaseline = "";
        }
        return result;
    }

    /**
     * Waits cooperatively for a sell request to produce an observable inventory change.
     * See ForItemBuy: the local inventory delta is a practical fallback for the event signal
     * used by Skua, but cannot distinguish unrelated inventory updates from a server ack.
     */
    public function ForItemSell(timeout:Int = 10):Bool {
        var effective = OverrideTimeout ? ItemActionTimeout : timeout;
        if (Api.shop == null) return poll("item-sell:no-shop", false, ticksToMs(effective));
        var requestId = Api.shop.lastSellRequestId;
        if (requestId <= _lastSeenSellRequestId) {
            return poll("item-sell:no-new-request", false, ticksToMs(effective));
        }
        if (requestId != _activeSellRequestId) {
            if (_activeSellRequestId > 0) _states.remove("item-sell:" + Std.string(_activeSellRequestId));
            _activeSellRequestId = requestId;
            _activeSellBaseline = Api.shop.lastSellInventoryBefore;
        }
        var key = "item-sell:" + Std.string(_activeSellRequestId);
        var ready = Api.shop.getInventorySignature() != _activeSellBaseline;
        var result = poll(key, ready, ticksToMs(effective));
        if (result || lastStatus == "timeout") {
            _lastSeenSellRequestId = _activeSellRequestId;
            _activeSellRequestId = 0;
            _activeSellBaseline = "";
        }
        return result;
    }

    public function ForItemEquip(itemNameOrId:Dynamic, timeout:Int = 10):Bool {
        var effective = OverrideTimeout ? ItemActionTimeout : timeout;
        return forItemEquip(itemNameOrId, ticksToMs(effective, Std.int(WAIT_SLEEP / 2)));
    }

    public function forBankLoad(timeoutMs:Float = -1):Bool {
        var ready = Api.inventory != null && Api.inventory.isBankLoaded;
        return poll("bank-load", ready, timeoutMs < 0 ? defaultTimeoutMs : timeoutMs);
    }

    public function ForBankLoad(timeout:Int = 20):Bool {
        return forBankLoad(ticksToMs(timeout));
    }

    public function forBankToInventory(itemNameOrId:Dynamic, quantity:Int = 1, timeoutMs:Float = -1):Bool {
        var ready = Api.inventory != null && Api.inventory.getQuantity(itemNameOrId) >= quantity;
        return poll("bank-to-inventory:" + Std.string(itemNameOrId), ready, timeoutMs < 0 ? defaultTimeoutMs : timeoutMs);
    }

    public function ForBankToInventory(itemNameOrId:Dynamic, timeout:Int = 14):Bool {
        var effective = OverrideTimeout ? ItemActionTimeout : timeout;
        return forBankToInventory(itemNameOrId, 1, ticksToMs(effective, Std.int(WAIT_SLEEP / 2)));
    }

    public function forInventoryToBank(itemNameOrId:Dynamic, quantity:Int = 1, timeoutMs:Float = -1):Bool {
        var ready = Api.inventory != null && Api.inventory.getBankQuantity(Std.string(itemNameOrId)) >= quantity;
        return poll("inventory-to-bank:" + Std.string(itemNameOrId), ready, timeoutMs < 0 ? defaultTimeoutMs : timeoutMs);
    }

    public function ForInventoryToBank(itemNameOrId:Dynamic, timeout:Int = 14):Bool {
        var effective = OverrideTimeout ? ItemActionTimeout : timeout;
        // Match Skua's compatibility contract: wait until the item is no longer in
        // normal inventory. Keep the lower-camel helper quantity-aware for callers
        // that explicitly want to verify a bank transfer quantity.
        var ready = Api.game == null || Api.game.world == null ||
            (Api.inventory != null && Api.inventory.getQuantity(itemNameOrId) < 1);
        return poll("inventory-to-bank-compatible:" + Std.string(itemNameOrId), ready,
            ticksToMs(effective, Std.int(WAIT_SLEEP / 2)));
    }

    public function ForBankToHouseInventory(itemNameOrId:Dynamic, timeout:Int = 14):Bool {
        var effective = OverrideTimeout ? ItemActionTimeout : timeout;
        return poll("bank-to-house:" + Std.string(itemNameOrId), Api.inventory != null && Api.inventory.getHouseQuantity(Std.string(itemNameOrId)) >= 1, ticksToMs(effective, Std.int(WAIT_SLEEP / 2)));
    }

    public function ForHouseInventoryToBank(itemNameOrId:Dynamic, timeout:Int = 14):Bool {
        var effective = OverrideTimeout ? ItemActionTimeout : timeout;
        return poll("house-to-bank:" + Std.string(itemNameOrId), Api.inventory != null && Api.inventory.getHouseQuantity(Std.string(itemNameOrId)) < 1, ticksToMs(effective));
    }

    /**
     * Cooperative equivalent of Skua's For(Func<object>, value).
     * Unlike Skua's blocking wait, call this on successive script ticks until it returns true.
     */
    public function For(predicate:Dynamic, value:Dynamic, timeout:Int = 10, key:String = "for-value"):Bool {
        var ready = false;
        if (predicate != null && Reflect.isFunction(predicate)) {
            try {
                ready = Reflect.callMethod(null, predicate, []) == value;
            } catch (e:Dynamic) {
                ApiLogger.error("Wait", "Value predicate failed: " + Std.string(e));
            }
        }
        return poll(key + ":" + Std.string(value), ready, ticksToMs(timeout));
    }

    /** Cooperative predicate wait; this does not block or suspend the HScript call stack. */
    public function ForTrueAsync(predicate:Dynamic, timeout:Int = 10, key:String = "for-true-async"):Bool {
        return forTrue(key, predicate, ticksToMs(timeout));
    }

    /** Cooperative alias for scripts ported from Skua's asynchronous wait API. */
    public function ForAsync(predicate:Dynamic, value:Dynamic, timeout:Int = 10, key:String = "for-async"):Bool {
        return For(predicate, value, timeout, key);
    }

    /** Returns whether a Flash game action's cooldown has elapsed. */
    public function IsActionAvailable(action:String):Bool {
        if (action == null || action == "" || Api.game == null || Api.game.world == null) return false;
        var lockRoot:Dynamic = Reflect.field(Api.game.world, "lock");
        if (lockRoot == null) return false;

        var lockName = action;
        switch (action.toLowerCase()) {
            case "loadshop": lockName = "loadShop";
            case "loadenhshop": lockName = "loadEnhShop";
            case "loadhairshop": lockName = "loadHairShop";
            case "equipitem": lockName = "equipItem";
            case "unequipitem": lockName = "unequipItem";
            case "buyitem": lockName = "buyItem";
            case "sellitem": lockName = "sellItem";
            case "getmapitem": lockName = "getMapItem";
            case "tryquestcomplete": lockName = "tryQuestComplete";
            case "acceptquest": lockName = "acceptQuest";
            case "doia": lockName = "doIA";
            case "rest": lockName = "rest";
            case "who": lockName = "who";
            case "transfer": lockName = "tfer";
            case "tfer": lockName = "tfer";
            default: lockName = action;
        }

        var lock:Dynamic = Reflect.field(lockRoot, lockName);
        if (lock == null) return false;
        var timestamp:Dynamic = Reflect.field(lock, "ts");
        if (timestamp == null) timestamp = Reflect.field(lock, "TS");
        var cooldown:Dynamic = Reflect.field(lock, "cd");
        if (cooldown == null) cooldown = Reflect.field(lock, "CD");
        if (timestamp == null || cooldown == null) return false;
        return ApiTime.epochMs() - Std.parseFloat(Std.string(timestamp)) >= Std.parseFloat(Std.string(cooldown));
    }

    /** Waits cooperatively for an action cooldown to expire. */
    public function ForActionCooldown(action:String, timeout:Int = 40):Bool {
        var effective = OverrideTimeout ? GameActionTimeout : timeout;
        return poll("action-cooldown:" + action, IsActionAvailable(action), ticksToMs(effective));
    }

    /** Waits cooperatively until the current combat system reports a skill is usable. */
    public function ForSkillCooldown(index:Int, timeout:Int = 50):Bool {
        var ready = Api.combat != null && Api.combat.canUseSkill(index);
        return poll("skill-cooldown:" + index, ready, ticksToMs(timeout));
    }
}
