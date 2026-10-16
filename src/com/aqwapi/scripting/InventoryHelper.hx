package com.aqwapi.scripting;

import com.aqwapi.Api;

/**
 * Cross-container inventory prerequisite helper inspired by Skua's InvHelper.
 *
 * It checks temporary inventory, normal inventory, house inventory, and bank.
 * When requested, banked items are queued for withdrawal through the existing
 * InventoryManager; Check/HasAll/HasAny return false until the requested items
 * are actually available in inventory or another eligible container.
 */
class InventoryHelper {
    public function new() {}

    private function key(item:Dynamic):String {
        return item == null ? "" : StringTools.trim(Std.string(item));
    }

    private function asList(items:Dynamic):Array<String> {
        var result:Array<String> = [];
        if (items == null) return result;
        if (Std.isOfType(items, Array)) {
            for (item in (cast items:Array<Dynamic>)) {
                var value = key(item);
                if (value != "") result.push(value);
            }
        } else {
            var value = key(items);
            if (value.indexOf(",") >= 0) {
                for (part in value.split(",")) {
                    var trimmed = StringTools.trim(part);
                    if (trimmed != "") result.push(trimmed);
                }
            } else if (value != "") {
                result.push(value);
            }
        }
        return result;
    }

    private function available(item:String, quantity:Int, moveToInventory:Bool):Bool {
        if (Api.inventory == null || item == "") return false;
        var wanted = quantity < 1 ? 1 : quantity;

        if (Api.inventory.getTempQuantity(item) >= wanted) return true;
        if (Api.inventory.getQuantity(item) >= wanted) return true;
        if (Api.inventory.getHouseQuantity(item) >= wanted) return true;

        var bankQuantity = Api.inventory.getBankQuantity(item);
        var isBanked = Api.inventory.isInBank(item);
        if (bankQuantity < wanted && !(wanted == 1 && isBanked)) return false;

        if (!moveToInventory) return isBanked && (bankQuantity >= wanted || wanted == 1);
        Api.inventory.ensureUnbanked([item]);
        return Api.inventory.getQuantity(item) >= wanted;
    }

    public function check(item:Dynamic, quantity:Int = 1, moveToInventory:Bool = true):Bool {
        return available(key(item), quantity, moveToInventory);
    }

    public function hasAll(items:Dynamic, quantity:Int = 1, moveToInventory:Bool = true):Bool {
        var list = asList(items);
        if (list.length == 0) return true;
        var allAvailable = true;
        for (item in list) {
            if (!available(item, quantity, moveToInventory)) allAvailable = false;
        }
        return allAvailable;
    }

    public function hasAny(items:Dynamic, quantity:Int = 1, moveToInventory:Bool = true):Bool {
        var list = asList(items);
        if (list.length == 0) return true;
        for (item in list) {
            if (available(item, quantity, moveToInventory)) return true;
        }
        return false;
    }

    // PascalCase aliases for scripts ported from Skua's InvHelper.
    public function Check(item:Dynamic, quantity:Int = 1, moveToInventory:Bool = true):Bool {
        return check(item, quantity, moveToInventory);
    }

    public function HasAll(items:Dynamic, quantity:Int = 1, moveToInventory:Bool = true):Bool {
        return hasAll(items, quantity, moveToInventory);
    }

    public function HasAny(items:Dynamic, quantity:Int = 1, moveToInventory:Bool = true):Bool {
        return hasAny(items, quantity, moveToInventory);
    }
}
