package com.aqwapi.scripting;

import com.aqwapi.Api;
import com.aqwapi.utils.ApiLogger;

/**
 * Partial Skua-style packet/chat facade.
 *
 * Only operations with a concrete Haxe/client bridge are implemented here.
 * Packet methods are intentionally low-level: malformed packets can disconnect a client.
 */
class ScriptSend {
    public function new() {}

    /** Sends a raw server-bound packet using the client's SFC transport. */
    public function Packet(packet:String, type:String = "String"):Void {
        if (packet == null || Api.game == null || Api.game.sfc == null) return;
        var normalized = (type == null || StringTools.trim(type) == "") ? "String" : StringTools.trim(type);
        var methodName = "send" + normalized.charAt(0).toUpperCase() + normalized.substr(1);
        var method:Dynamic = Reflect.field(Api.game.sfc, methodName);
        if (method == null && normalized.toLowerCase() == "string") method = Reflect.field(Api.game.sfc, "sendString");
        if (method == null || !Reflect.isFunction(method)) {
            ApiLogger.warn("Send", "Client SFC method unavailable: " + methodName);
            return;
        }
        try {
            Reflect.callMethod(Api.game.sfc, method, [packet]);
        } catch (e:Dynamic) {
            ApiLogger.warn("Send", "Packet send failed: " + Std.string(e));
        }
    }

    /** Sends a packet through the client's sendClientPacket helper when exposed by this build. */
    public function ClientPacket(packet:String, type:String = "str"):Void {
        if (packet == null || Api.game == null) return;
        var candidates:Array<Dynamic> = [Api.game];
        try { if (Api.game.world != null) candidates.push(Api.game.world); } catch (_:Dynamic) {}
        try { if (Api.game.ui != null) candidates.push(Api.game.ui); } catch (_:Dynamic) {}
        for (owner in candidates) {
            if (owner == null) continue;
            var method:Dynamic = null;
            try { method = Reflect.field(owner, "sendClientPacket"); } catch (_:Dynamic) {}
            if (method != null && Reflect.isFunction(method)) {
                try {
                    Reflect.callMethod(owner, method, [packet, type]);
                    return;
                } catch (e:Dynamic) {
                    ApiLogger.warn("Send", "Client packet send failed: " + Std.string(e));
                    return;
                }
            }
        }
        ApiLogger.warn("Send", "sendClientPacket is not exposed by this client build.");
    }

    private function clientMessage(message:String, sentBy:String, kind:String):Void {
        var text = message == null ? "" : message;
        var sender = (sentBy == null || sentBy == "") ? "Skua" : sentBy;
        ClientPacket("%xt%chatm%0%" + kind + "~" + text + "%" + sender + "%", "str");
    }

    public function ClientEvent(message:String, sentBy:String = "Skua"):Void {
        clientMessage(message, sentBy, "event");
    }
    public function ClientGuild(message:String, sentBy:String = "Skua"):Void {
        clientMessage(message, sentBy, "guild");
    }
    public function ClientModerator(message:String, sentBy:String = "Skua"):Void {
        clientMessage(message, sentBy, "moderator");
    }
    public function ClientServer(message:String, sentBy:String = "Skua"):Void {
        clientMessage(message, sentBy, "server");
    }
    public function ClientWarning(message:String, sentBy:String = "Skua"):Void {
        clientMessage(message, sentBy, "warning");
    }
    public function ClientWhisper(message:String, sentBy:String = "Skua"):Void {
        clientMessage(message, sentBy, "whisper");
    }
    public function ClientZone(message:String, sentBy:String = "Skua"):Void {
        clientMessage(message, sentBy, "zone");
    }

    /** Sends a server-side whisper packet; this is not a client-only chat message. */
    public function Whisper(username:String, message:String):Void {
        if (username == null || message == null || Api.game == null || Api.game.sfc == null) return;
        Packet("%xt%zm%whisper%1%" + message + "%" + username + "%", "String");
    }
}
