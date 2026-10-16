package com.aqwapi.net;

import com.aqwapi.Api;
import haxe.Json;

/**
 * Transport-neutral JSON command router for the external client bridge.
 *
 * The Flash/socket host should pass each decoded request line to handleLine()
 * and write the returned JSON line back to the same requesting client. This
 * class does not open sockets or discover the AQW root by itself.
 */
class BridgeCommandRouter {
    public static inline var PROTOCOL_VERSION:String = "1";

    public function new() {}

    public function handleLine(line:String):String {
        var request:Dynamic = null;
        var requestId:Dynamic = null;
        var instanceId:Dynamic = 0;

        try {
            request = Json.parse(line);
            requestId = Reflect.field(request, "id");
            var requestedInstance:Dynamic = Reflect.field(request, "instanceId");
            if (requestedInstance != null) instanceId = requestedInstance;

            var command:String = asString(Reflect.field(request, "type"), "");
            var data:Dynamic = dispatch(command, request);
            return Json.stringify({
                id: requestId,
                instanceId: instanceId,
                success: true,
                data: data
            });
        } catch (e:Dynamic) {
            return Json.stringify({
                id: requestId,
                instanceId: instanceId,
                success: false,
                data: null,
                error: Std.string(e)
            });
        }
    }

    private function dispatch(command:String, request:Dynamic):Dynamic {
        switch (command) {
            case "Ping":
                return {
                    protocolVersion: PROTOCOL_VERSION,
                    apiLoaded: Api.game != null,
                    apiInitialized: Api.game != null && Api.player != null
                };

            case "GetCapabilities":
                return {
                    protocolVersion: PROTOCOL_VERSION,
                    commands: ["Ping", "GetCapabilities", "GetState", "JoinMap", "RunScript", "StopScript", "GetScriptStatus"]
                };

            case "GetState":
                return getState();

            case "JoinMap":
                requireInitialized();
                var mapName = asString(Reflect.field(request, "map"), "");
                if (mapName == "") throw "JoinMap requires a non-empty 'map' field.";
                var cell = asNullableString(Reflect.field(request, "cell"));
                var pad = asNullableString(Reflect.field(request, "pad"));
                Api.map.join(mapName, cell, pad);
                return { accepted: true, map: mapName, cell: cell, pad: pad };

            case "RunScript":
                requireInitialized();
                var scriptCode = asString(Reflect.field(request, "script"), "");
                if (scriptCode == "") throw "RunScript requires a non-empty 'script' field.";
                if (Api.hscript == null) throw "HScript engine is not initialized.";
                if (!Api.hscript.loadScript(scriptCode)) {
                    throw "HScript rejected the script: " + Api.hscript.statusText;
                }
                Api.hscript.start();
                return { accepted: true, status: Api.hscript.statusText };

            case "StopScript":
                if (Api.hscript != null) Api.hscript.stop();
                return { accepted: true, running: Api.hscript != null && Api.hscript.isRunning };

            case "GetScriptStatus":
                return {
                    running: Api.hscript != null && Api.hscript.isRunning,
                    status: Api.hscript != null ? Api.hscript.statusText : "not-initialized"
                };

            default:
                throw "Unsupported bridge command: " + command;
        }
    }

    private function getState():Dynamic {
        var initialized = Api.game != null && Api.player != null;
        return {
            protocolVersion: PROTOCOL_VERSION,
            ready: initialized,
            player: {
                username: initialized ? Api.player.username : "",
                level: initialized ? Api.player.level : 0,
                hp: initialized ? Api.player.hp : 0,
                mp: initialized ? Api.player.mp : 0,
                gold: initialized ? Api.player.gold : 0,
                alive: initialized ? Api.player.isAlive : false,
                inCombat: initialized ? Api.player.isInCombat : false,
                cell: initialized ? Api.player.cell : "",
                pad: initialized ? Api.player.pad : ""
            },
            map: initialized ? Api.map.currentMap : ""
        };
    }

    private function requireInitialized():Void {
        if (Api.game == null || Api.player == null || Api.map == null) {
            throw "AQW API is not initialized for a game instance.";
        }
    }

    private static function asString(value:Dynamic, fallback:String):String {
        return value == null ? fallback : Std.string(value);
    }

    private static function asNullableString(value:Dynamic):String {
        return value == null ? null : Std.string(value);
    }
}
