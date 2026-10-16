package com.aqwapi.scripting;

import com.aqwapi.Api;
import com.aqwapi.data.ItemDTO;
import com.aqwapi.utils.ApiTime;
import com.aqwapi.utils.ApiLogger;

/**
 * First-pass Skua-style bank facade.
 *
 * Transfers are cooperative: call EnsureToInventory on successive HScript ticks.
 * Load(waitForLoad=true) starts loading but cannot block/suspend the HScript stack.
 */
class ScriptBank {
    public var Loaded(get, set):Bool;
    @:getter(Loaded)
    public function get_Loaded_prop():Bool { return Api.inventory != null && Api.inventory.isBankLoaded; }
    public function get_Loaded():Bool { return Api.inventory != null && Api.inventory.isBankLoaded; }
    @:setter(Loaded)
    public function set_Loaded_prop(value:Bool):Void { if (Api.inventory != null) Api.inventory.setBankLoaded(value); }
    public function set_Loaded(value:Bool):Bool { return Api.inventory != null ? Api.inventory.setBankLoaded(value) : false; }

    public var Slots(get, never):Int;
    @:getter(Slots)
    public function get_Slots_prop():Int { return Api.inventory != null ? Api.inventory.maxBankSlots : 0; }
    public function get_Slots():Int { return Api.inventory != null ? Api.inventory.maxBankSlots : 0; }

    public var UsedSlots(get, never):Int;
    @:getter(UsedSlots)
    public function get_UsedSlots_prop():Int { return Api.inventory != null ? Api.inventory.usedBankSlots : 0; }
    public function get_UsedSlots():Int { return Api.inventory != null ? Api.inventory.usedBankSlots : 0; }

    public var FreeSlots(get, never):Int;
    @:getter(FreeSlots)
    public function get_FreeSlots_prop():Int { return Api.inventory != null ? Api.inventory.freeBankSlots : 0; }
    public function get_FreeSlots():Int { return Api.inventory != null ? Api.inventory.freeBankSlots : 0; }

    public var Items(get, never):Array<ItemDTO>;
    @:getter(Items)
    public function get_Items_prop():Array<ItemDTO> { return Api.inventory != null ? Api.inventory.getBankItems() : []; }
    public function get_Items():Array<ItemDTO> { return Api.inventory != null ? Api.inventory.getBankItems() : []; }

    public function new() {}

    public function Open():Void {
        if (Api.inventory != null) Api.inventory.openBank();
    }

    public function Load(waitForLoad:Bool = true):Void {
        if (Api.inventory != null) Api.inventory.loadBank();
        // waitForLoad is intentionally non-blocking in HScript; use Bot.Wait.ForBankLoad().
    }

    public function Contains(item:Dynamic, quantity:Int = 1):Bool {
        if (Api.inventory == null || item == null) return false;
        var wanted = quantity < 0 ? 1 : quantity;
        return wanted == 0 || Api.inventory.getBankQuantity(Std.string(item)) >= wanted;
    }

    public function GetQuantity(item:Dynamic):Int {
        return Api.inventory != null && item != null ? Api.inventory.getBankQuantity(Std.string(item)) : 0;
    }

    public function GetItem(item:Dynamic):ItemDTO {
        if (item == null || Api.inventory == null) return null;
        var key = Std.string(item);
        var id = com.aqwapi.utils.ApiUtils.parseInt(key, 0);
        for (entry in Api.inventory.getBankItems()) {
            if (entry == null) continue;
            if (id > 0 ? entry.itemId == id : entry.name.toLowerCase() == key.toLowerCase()) return entry;
        }
        return null;
    }

    public function ToInventory(item:Dynamic):Bool {
        if (item == null || Api.inventory == null) return false;
        if (Api.inventory.getQuantity(item) > 0) return true;
        if (Api.inventory.getBankQuantity(Std.string(item)) <= 0) return false;
        Api.inventory.ensureUnbanked([item]);
        return Api.inventory.getQuantity(item) > 0;
    }

    public function EnsureToInventory(item:Dynamic, loadBank:Bool = true):Bool {
        if (item == null || Api.inventory == null) return false;
        if (Api.inventory.getQuantity(item) > 0) return true;
        if (!Api.inventory.isBankLoaded) {
            if (loadBank) Api.inventory.loadBank();
            return false;
        }
        return ToInventory(item);
    }

    private var _swapStates:Map<String, Dynamic> = new Map<String, Dynamic>();

    private function swapKey(invItem:Dynamic, bankItem:Dynamic):String {
        return StringTools.trim(Std.string(invItem)).toLowerCase() + "->" +
            StringTools.trim(Std.string(bankItem)).toLowerCase();
    }

    /**
     * Cooperative inventory/bank swap. Call on successive script ticks until true.
     * It queues the inventory-to-bank leg first, then the bank-to-inventory leg,
     * and only reports completion after the resulting local quantities are observed.
     */
    public function Swap(invItem:Dynamic, bankItem:Dynamic):Bool {
        if (Api.inventory == null || invItem == null || bankItem == null) return false;
        var invKey = StringTools.trim(Std.string(invItem));
        var bankKey = StringTools.trim(Std.string(bankItem));
        if (invKey == "" || bankKey == "") return false;

        // Treat the desired postcondition as success, including when the swap happened
        // before this helper was first called.
        if (Api.inventory.getQuantity(bankKey) > 0 && Api.inventory.getBankQuantity(invKey) > 0) return true;

        var key = swapKey(invKey, bankKey);
        var state:Dynamic = _swapStates.get(key);
        if (state == null) {
            if (!Api.inventory.isBankLoaded) return false;
            var invQty = Api.inventory.getQuantity(invKey);
            var bankQty = Api.inventory.getBankQuantity(bankKey);
            if (invQty <= 0 || bankQty <= 0) return false;

            state = {
                phase: 1,
                startedAt: ApiTime.now(),
                phaseStartedAt: ApiTime.now(),
                invItem: invKey,
                bankItem: bankKey,
                invQtyBefore: invQty,
                bankInvQtyBefore: Api.inventory.getBankQuantity(invKey),
                bankQtyBefore: bankQty,
                invBankQtyBefore: Api.inventory.getQuantity(bankKey)
            };
            _swapStates.set(key, state);
            Api.inventory.bank([invKey]);
            return false;
        }

        // Avoid leaving a script waiting forever if a transfer is rejected, an item is
        // protected/equipped, or the client never updates its local bank state.
        var now = ApiTime.now();
        if (state.phase == 3) return false;
        if (now - state.phaseStartedAt >= 20000) {
            state.phase = 3;
            ApiLogger.warn("Bank", "Swap timed out for " + state.invItem + " <-> " + state.bankItem + ". Use ResetSwap before retrying.");
            return false;
        }

        if (state.phase == 1) {
            var inventoryLegObserved = Api.inventory.getQuantity(state.invItem) < state.invQtyBefore ||
                Api.inventory.getBankQuantity(state.invItem) > state.bankInvQtyBefore;
            if (!inventoryLegObserved) return false;

            state.phase = 2;
            state.phaseStartedAt = now;
            state.invBankQtyBefore = Api.inventory.getQuantity(state.bankItem);
            state.bankQtyBefore = Api.inventory.getBankQuantity(state.bankItem);
            Api.inventory.ensureUnbanked([state.bankItem]);
            return false;
        }

        if (state.phase == 2) {
            var bankLegObserved = Api.inventory.getQuantity(state.bankItem) > state.invBankQtyBefore ||
                Api.inventory.getBankQuantity(state.bankItem) < state.bankQtyBefore;
            if (!bankLegObserved) return false;
            _swapStates.remove(key);
            return true;
        }

        _swapStates.remove(key);
        return false;
    }

    /** Clears a completed/failed cooperative swap state so the script may retry it. */
    public function ResetSwap(invItem:Dynamic, bankItem:Dynamic):Void {
        if (invItem == null || bankItem == null) return;
        _swapStates.remove(swapKey(invItem, bankItem));
    }

    /** Cooperative Swap alias; loadBank controls whether an unloaded bank is opened. */
    public function EnsureSwap(invItem:Dynamic, bankItem:Dynamic, loadBank:Bool = true):Bool {
        if (Api.inventory == null) return false;
        if (!Api.inventory.isBankLoaded) {
            if (loadBank) Api.inventory.loadBank();
            return false;
        }
        return Swap(invItem, bankItem);
    }

}
