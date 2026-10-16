package com.aqwapi.scripting;

import hscript.Interp;
import com.aqwapi.Api;

class ScriptInterp extends Interp {
    public function new() {
        super();
    }

    override function resolve(id:String):Dynamic {
        switch (id) {
            case "api", "bot", "Api", "Bot": return Api;
            case "core", "coreBots", "CoreBots": return CoreBots;
            case "handlers": return ScriptHandlers.SINGLETON;
            case "send": return Api.send;
            case "reputation": return Api.reputation;
            case "invHelper": return Api.invHelper;
            case "wait": return Api.wait;
            case "player": return Api.player;
            case "combat": return Api.combat;
            case "map": return Api.map;
            case "quests": return Api.quest;
            case "inventory", "inv", "bank": return Api.inventory;
            case "tempInv", "tempinv": return Api.tempInv;
            case "house": return Api.house;
            case "drop", "drops": return Api.drop;
            case "shop", "shops": return Api.shop;
            case "monster", "monsters": return Api.monster;
            case "enhancement", "enhancements": return Api.enhancement;
            case "skills": return Api.skills;
            case "aura", "auras": return Api.aura;
            case "visual": return Api.visual;
            case "party": return Api.party;
            case "blacklist": return Api.blacklist;
            case "script": return Api.script;
            case "events": return Api.dispatcher;
            case "ApiTime": return com.aqwapi.utils.ApiTime;
            case "ApiUtils": return com.aqwapi.utils.ApiUtils;
            case "ApiJson": return com.aqwapi.utils.ApiJson;
            case "ApiStorage": return com.aqwapi.utils.ApiStorage;
        }
        if (ScriptBindings.hasShortcut(id)) {
            return ScriptBindings.getShortcut(id);
        }
        return super.resolve(id);
    }

    /**
     * Identity test for the `api` / `bot` namespace.
     *
     * Left as `==` on purpose. Haxe 4 dropped `Std.refEq`, and the alternatives are worse: a
     * `SCRIPT_IDENTITY` marker on Api would make this depend on `Reflect.getProperty` returning
     * statics for a Class object, which cannot be verified without a Flash runtime and would break
     * every `api.something` access if it did not.
     */
    private static inline function isApiNamespace(o:Dynamic):Bool {
        return o != null && o == Api;
    }

    override function get(o:Dynamic, f:String):Dynamic {
        if (o == null) return null;
        if (isApiNamespace(o)) {
            // PascalCase service aliases mirror the shape of Skua's Bot interface.
            // These aliases expose existing Haxe managers; they do not imply that every
            // Skua member or behavior is implemented on the returned manager.
            switch (f) {
                case "Handlers": return ScriptHandlers.SINGLETON;
                case "Send": return Api.send;
                case "Reputation": return Api.reputation;
                case "InvHelper": return Api.invHelper;
                case "Wait": return Api.wait;
                case "Map": return Api.map;
                case "Player": return Api.player;
                case "Combat", "Kill", "Hunt": return Api.combat;
                case "Quests", "Quest": return Api.quest;
                case "Inventory": return Api.inventory;
                case "Bank": return Api.bank;
                case "TempInv": return Api.tempInv;
                case "House": return Api.house;
                case "Drops", "Drop": return Api.drop;
                case "Shops", "Shop": return Api.shop;
                case "Monsters", "Monster": return Api.monster;
                case "Skills", "Skill": return Api.skills;
                case "Enhancements", "Enhancement": return Api.enhancement;
                case "Party": return Api.party;
                case "Blacklist", "BlackList": return Api.blacklist;
                case "Events": return Api.dispatcher;
            }
            // Existing lowercase Api properties and shortcut names remain supported.
            var v:Dynamic = Reflect.getProperty(Api, f);
            if (v != null) return v;

            // Otherwise check registered shortcuts from ScriptBindings
            if (ScriptBindings.hasShortcut(f)) {
                return ScriptBindings.getShortcut(f);
            }
        }
        // General PascalCase -> lowerCamel fallback makes existing Haxe manager
        // members readable with Skua-style names without duplicating their logic.
        // Use reflection inside try/catch before falling back to hscript's strict
        // resolver, which may throw immediately for an unknown uppercase field.
        if (f != null && f.length > 0 && f.charAt(0) == f.charAt(0).toUpperCase()) {
            var direct:Dynamic = null;
            try {
                direct = Reflect.getProperty(o, f);
            } catch (_:Dynamic) {}
            if (direct != null) return direct;
            var lowerName = f.charAt(0).toLowerCase() + f.substr(1);
            var lowerValue:Dynamic = null;
            try {
                lowerValue = Reflect.getProperty(o, lowerName);
            } catch (_:Dynamic) {}
            if (lowerValue != null) return lowerValue;
        }
        return super.get(o, f);
    }

    override function fcall(o:Dynamic, f:String, args:Array<Dynamic>):Dynamic {
        if (o == null) return null;
        if (isApiNamespace(o) && ScriptBindings.hasShortcut(f)) {
            var fn:Dynamic = ScriptBindings.getShortcut(f);
            return call(null, fn, args);
        }
        // If a PascalCase member is not explicitly implemented, try its lowerCamel
        // counterpart. Only invoke it when reflection confirms that it is callable.
        if (f != null && f.length > 0 && f.charAt(0) == f.charAt(0).toUpperCase()) {
            var directMethod:Dynamic = null;
            try {
                directMethod = Reflect.getProperty(o, f);
            } catch (_:Dynamic) {}
            if (directMethod != null && Reflect.isFunction(directMethod)) {
                return super.fcall(o, f, args);
            }
            var lowerName = f.charAt(0).toLowerCase() + f.substr(1);
            var lowerMethod:Dynamic = null;
            try {
                lowerMethod = Reflect.getProperty(o, lowerName);
            } catch (_:Dynamic) {}
            if (lowerMethod != null && Reflect.isFunction(lowerMethod)) {
                return call(o, lowerMethod, args);
            }
        }
        return super.fcall(o, f, args);
    }

    override function call(o:Dynamic, f:Dynamic, args:Array<Dynamic>):Dynamic {
        if (f == null) return null;
        return super.call(o, f, args);
    }

    /**
     * Applies the assignment form of the two drop-acceptance flags.
     *
     * `acceptAllDrops` and `acceptAcDrops` are bound as functions, so `acceptAllDrops()` already
     * works. Plain assignment would otherwise be silently dropped: `resolve()` returns the function
     * object on every read no matter what sits in `variables`, so `acceptAllDrops = true` would be a
     * no-op. `expr` is the one hook that reliably reaches an override here - hscript calls it as
     * `me.expr(...)`, so it dispatches dynamically, while `setVar` and `assign` are bound as method
     * values into `binops` and would not. Only the two binding names are accepted, so the assignment
     * form can no longer diverge from the call form as separate spellings.
     */
    override function expr(e:hscript.Expr):Dynamic {
        #if hscriptPos
        var exprDef = e.e;
        #else
        var exprDef = e;
        #end
        switch (exprDef) {
            case EBinop("=", e1, e2):
                #if hscriptPos
                var ed1 = e1.e;
                #else
                var ed1 = e1;
                #end
                switch (ed1) {
                    case EIdent(id):
                        if (id == "acceptAllDrops" || id == "acceptAcDrops") {
                            var v:Dynamic = expr(e2);
                            if (Api.drop != null) {
                                if (id == "acceptAllDrops") Api.drop.acceptAllDrops(v == true);
                                else Api.drop.acceptAcDrops(v == true);
                            }
                            return v;
                        }
                        if (id == "lagKiller" || id == "hidePlayers" || id == "disableSkillAnims" || id == "disableMonsterAnims" || id == "cleanArena" || id == "hideMonsters") {
                            var v:Dynamic = expr(e2);
                            if (Api.visual != null) {
                                switch (id) {
                                    case "lagKiller": Api.visual.lagKiller = (v == true);
                                    case "hidePlayers": Api.visual.hidePlayers = (v == true);
                                    case "disableSkillAnims": Api.visual.disableSkillAnims = (v == true);
                                    case "disableMonsterAnims": Api.visual.disableMonsterAnims = (v == true);
                                    case "cleanArena": Api.visual.cleanArena = (v == true);
                                    case "hideMonsters": Api.visual.hideMonsters = (v == true);
                                }
                            }
                            return v;
                        }
                    default:
                }
            default:
        }
        return super.expr(e);
    }
}
