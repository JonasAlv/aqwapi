package com.aqwapi.scripting;

import com.aqwapi.Api;
import com.aqwapi.data.ItemDTO;

/** Skua-style view of temporary inventory; never conflates it with normal inventory. */
class ScriptTempInv {
    public var Items(get, never):Array<ItemDTO>;
    @:getter(Items)
    public function get_Items_prop():Array<ItemDTO> { return Api.inventory != null ? Api.inventory.getTempItems() : []; }
    public function get_Items():Array<ItemDTO> { return Api.inventory != null ? Api.inventory.getTempItems() : []; }

    public function new() {}

    public function Contains(item:Dynamic, quantity:Int = 1):Bool {
        if (Api.inventory == null || item == null) return false;
        var wanted = quantity < 0 ? 1 : quantity;
        return wanted == 0 || Api.inventory.getTempQuantity(Std.string(item)) >= wanted;
    }

    public function GetQuantity(item:Dynamic):Int {
        return Api.inventory != null && item != null ? Api.inventory.getTempQuantity(Std.string(item)) : 0;
    }

    public function GetItem(item:Dynamic):ItemDTO {
        if (item == null || Api.inventory == null) return null;
        var key = Std.string(item);
        var id = com.aqwapi.utils.ApiUtils.parseInt(key, 0);
        for (entry in Api.inventory.getTempItems()) {
            if (entry == null) continue;
            if (id > 0 ? entry.itemId == id : entry.name.toLowerCase() == key.toLowerCase()) return entry;
        }
        return null;
    }

    public function IsMaxStack(item:Dynamic):Bool {
        var entry = GetItem(item);
        return entry != null && entry.maxStack > 0 && entry.quantity >= entry.maxStack;
    }
}
