package com.aqwapi.scripting;

import com.aqwapi.Api;

/**
 * Partial Skua-style reputation service backed by the existing player faction lookup.
 * Faction enumeration and reputation farming are intentionally not inferred here.
 */
class ScriptReputation {
    public function new() {}

    public function GetRank(factionName:String):Int {
        return Api.player != null && factionName != null ? Api.player.getFactionRank(factionName) : 0;
    }

    public function getRank(factionName:String):Int {
        return GetRank(factionName);
    }

    public function HasRank(factionName:String, requiredRank:Int):Bool {
        return GetRank(factionName) >= requiredRank;
    }

    public function hasRank(factionName:String, requiredRank:Int):Bool {
        return HasRank(factionName, requiredRank);
    }
}
