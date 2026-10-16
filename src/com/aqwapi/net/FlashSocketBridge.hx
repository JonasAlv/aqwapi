package com.aqwapi.net;

import com.aqwapi.Api;
import com.aqwapi.utils.ApiLogger;
import flash.events.Event;
import flash.events.IOErrorEvent;
import flash.events.ProgressEvent;
import flash.events.SecurityErrorEvent;
import flash.net.Socket;
import haxe.Json;

/**
 * Local TCP adapter for aqw-elec's Flash bridge port (4242).
 *
 * Call Api.init(gameRoot) first, then Api.startBridge(). The caller is
 * responsible for supplying the correct AQW game root to Api.init().
 */
class FlashSocketBridge {
    private var _host:String;
    private var _port:Int;
    private var _socket:Socket;
    private var _router:BridgeCommandRouter;
    private var _buffer:String = "";
    private var _started:Bool = false;
    private var _assignedInstanceId:Int = -1;

    public var isConnected(get, never):Bool;
    public function get_isConnected():Bool {
        return _socket != null && _socket.connected;
    }

    public function new(host:String = "127.0.0.1", port:Int = 4242) {
        _host = host;
        _port = port;
        _router = new BridgeCommandRouter();
    }

    public function start():Void {
        if (_started && isConnected) return;
        stop();
        _started = true;
        _buffer = "";
        _socket = new Socket();
        _socket.addEventListener(Event.CONNECT, onConnect);
        _socket.addEventListener(ProgressEvent.SOCKET_DATA, onSocketData);
        _socket.addEventListener(Event.CLOSE, onClose);
        _socket.addEventListener(IOErrorEvent.IO_ERROR, onIoError);
        _socket.addEventListener(SecurityErrorEvent.SECURITY_ERROR, onSecurityError);

        try {
            _socket.connect(_host, _port);
            ApiLogger.info("Bridge", "Connecting to local game host " + _host + ":" + _port);
        } catch (e:Dynamic) {
            ApiLogger.warn("Bridge", "Could not connect to local game host: " + Std.string(e));
            _started = false;
        }
    }

    public function stop():Void {
        _started = false;
        if (_socket != null) {
            try {
                _socket.removeEventListener(Event.CONNECT, onConnect);
                _socket.removeEventListener(ProgressEvent.SOCKET_DATA, onSocketData);
                _socket.removeEventListener(Event.CLOSE, onClose);
                _socket.removeEventListener(IOErrorEvent.IO_ERROR, onIoError);
                _socket.removeEventListener(SecurityErrorEvent.SECURITY_ERROR, onSecurityError);
                if (_socket.connected) _socket.close();
            } catch (_:Dynamic) {}
            _socket = null;
        }
        _buffer = "";
        _assignedInstanceId = -1;
    }

    private function onConnect(_:Event):Void {
        ApiLogger.info("Bridge", "Connected to local game host bridge.");
        writeLine({
            type: "connected",
            clientId: "aqw-haxe-api"
        });
    }

    private function onSocketData(_:ProgressEvent):Void {
        if (_socket == null || !_socket.connected) return;

        try {
            _buffer += _socket.readUTFBytes(_socket.bytesAvailable);
            var newline = _buffer.indexOf("\n");
            while (newline >= 0) {
                var line = StringTools.trim(_buffer.substr(0, newline));
                _buffer = _buffer.substr(newline + 1);
                if (line != "") handleLine(line);
                newline = _buffer.indexOf("\n");
            }
        } catch (e:Dynamic) {
            ApiLogger.warn("Bridge", "Failed reading bridge request: " + Std.string(e));
        }
    }

    private function handleLine(line:String):Void {
        try {
            var request:Dynamic = Json.parse(line);
            var requestType:String = (Reflect.field(request, "type") != null)
                ? Std.string(Reflect.field(request, "type"))
                : "";

            // Host handshake/control frames are not API commands.
            if (requestType == "instance_assigned") {
                var value:Dynamic = Reflect.field(request, "instanceId");
                if (value != null) _assignedInstanceId = Std.parseInt(Std.string(value));
                ApiLogger.debug("Bridge", "Host assigned game instance " + _assignedInstanceId);
                return;
            }

            var response = _router.handleLine(line);
            writeRawLine(response);
        } catch (e:Dynamic) {
            ApiLogger.warn("Bridge", "Could not dispatch bridge request: " + Std.string(e));
            writeLine({
                id: null,
                instanceId: _assignedInstanceId,
                success: false,
                data: null,
                error: Std.string(e)
            });
        }
    }

    private function writeLine(value:Dynamic):Void {
        writeRawLine(Json.stringify(value));
    }

    private function writeRawLine(line:String):Void {
        if (_socket == null || !_socket.connected) return;
        try {
            _socket.writeUTFBytes(line + "\n");
            _socket.flush();
        } catch (e:Dynamic) {
            ApiLogger.warn("Bridge", "Failed writing bridge response: " + Std.string(e));
        }
    }

    private function onClose(_:Event):Void {
        ApiLogger.warn("Bridge", "Local game host bridge disconnected.");
        _started = false;
    }

    private function onIoError(event:IOErrorEvent):Void {
        ApiLogger.warn("Bridge", "Socket I/O error: " + event.text);
        _started = false;
    }

    private function onSecurityError(event:SecurityErrorEvent):Void {
        ApiLogger.warn("Bridge", "Socket security error: " + event.text);
        _started = false;
    }
}
