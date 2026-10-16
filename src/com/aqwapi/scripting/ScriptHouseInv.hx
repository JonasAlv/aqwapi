package com.aqwapi.scripting;

import com.aqwapi.Api;
import com.aqwapi.data.ItemDTO;

/** Skua-style view of house inventory; checks only house storage. */
class ScriptHouseInv {
    public var Items(get, never):Array<ItemDTO>;
    @:getter(Items)
    public function get_Items_prop():Array<ItemDTO> { return Api.inventory != null ? Api.inventory.getHouseItems() : []; }
    public function get_Items():Array<ItemDTO> { return Api.inventory != null ? Api.inventory.getHouseItems() : []; }

    public function new() {}

    public function Contains(item:Dynamic, quantity:Int = 1):Bool {
        if (Api.inventory == null || item == null) return false;
        var wanted = quantity < 0 ? 1 : quantity;
        return wanted == 0 || Api.inventory.getHouseQuantity(Std.string(item)) >= wanted;
    }

    public function GetQuantity(item:Dynamic):Int {
        return Api.inventory != null && item != null ? Api.inventory.getHouseQuantity(Std.string(item)) : 0;
    }

    public function GetItem(item:Dynamic):ItemDTO {
        if (item == null || Api.inventory == null) return null;
        var key = Std.string(item);
        var id = com.aqwapi.utils.ApiUtils.parseInt(key, 0);
        for (entry in Api.inventory.getHouseItems()) {
            if (entry == null) continue;
            if (id > 0 ? entry.itemId == id : entry.name.toLowerCase() == key.toLowerCase()) return entry;
        }
        return null;
    }

    public function IsEquipped(item:Dynamic):Bool {
        return Api.inventory != null && item != null && Api.inventory.isEquipped(item);
    }

    public function IsWorn(item:Dynamic):Bool {
        return Api.inventory != null && item != null && Api.inventory.isWorn(item);
    }
}
