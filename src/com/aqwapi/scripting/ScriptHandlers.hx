package com.aqwapi.scripting;

import com.aqwapi.Api;
import com.aqwapi.utils.ApiLogger;

/**
 * Tick-driven counterpart of Skua's IScriptHandlers.
 *
 * Skua defines one tick as 20ms. HScriptEngine currently wakes at tickInterval
 * (100ms by default), so this manager honors the requested interval as closely as
 * the host tick permits. It never sleeps or blocks the Flash runtime.
 */
class ScriptHandlers {
    private static var _instance:ScriptHandlers;

    public static var SINGLETON(get, never):ScriptHandlers;
    @:getter(SINGLETON)
    public static function get_SINGLETON_prop():ScriptHandlers {
        if (_instance == null) _instance = new ScriptHandlers();
        return _instance;
    }
    public static function get_SINGLETON():ScriptHandlers {
        if (_instance == null) _instance = new ScriptHandlers();
        return _instance;
    }

    private var _handlers:Array<ScriptHandler> = [];
    private var _nextId:Int = 0;

    public var currentHandlers(get, never):Array<ScriptHandler>;
    @:getter(currentHandlers)
    public function get_currentHandlers():Array<ScriptHandler> {
        return _handlers.copy();
    }

    public var CurrentHandlers(get, never):Array<ScriptHandler>;
    @:getter(CurrentHandlers)
    public function get_CurrentHandlers():Array<ScriptHandler> {
        return _handlers.copy();
    }

    public function new() {}

    public function registerHandler(ticks:Int, callback:Dynamic, name:String = null):ScriptHandler {
        if (callback == null || !Reflect.isFunction(callback)) {
            ApiLogger.warn("Handlers", "Ignoring handler registration without a callable callback.");
            return null;
        }
        var handlerName = (name == null || StringTools.trim(name) == "")
            ? "haxe-handler-" + (_nextId++)
            : name;
        var handler = new ScriptHandler(handlerName, ticks, callback);
        _handlers.push(handler);
        return handler;
    }

    public function RegisterHandler(ticks:Int, callback:Dynamic, name:String = null):ScriptHandler {
        return registerHandler(ticks, callback, name);
    }

    public function registerOnce(ticks:Int, callback:Dynamic, name:String = null):ScriptHandler {
        if (callback == null || !Reflect.isFunction(callback)) {
            ApiLogger.warn("Handlers", "Ignoring one-shot handler registration without a callable callback.");
            return null;
        }
        var once:Dynamic = function(bot:Dynamic):Bool {
            Reflect.callMethod(null, callback, [bot]);
            return false;
        };
        return registerHandler(ticks, once, name);
    }

    public function RegisterOnce(ticks:Int, callback:Dynamic, name:String = null):ScriptHandler {
        return registerOnce(ticks, callback, name);
    }

    public function remove(name:String):Bool {
        if (name == null) return false;
        var before = _handlers.length;
        _handlers = _handlers.filter(function(handler) return handler.name != name);
        return _handlers.length < before;
    }

    public function Remove(nameOrHandler:Dynamic):Bool {
        if (Std.isOfType(nameOrHandler, String)) return remove(cast nameOrHandler);
        return removeHandler(cast nameOrHandler);
    }

    public function removeHandler(handler:ScriptHandler):Bool {
        if (handler == null) return false;
        return _handlers.remove(handler);
    }

    public function clear():Void {
        _handlers = [];
    }

    public function Clear():Void {
        clear();
    }

    /**
     * Called by HScriptEngine once per host tick while a script is running.
     * A callback returning false is removed; exceptions are logged and removed
     * so one bad callback cannot permanently break the script tick loop.
     */
    public function tick(elapsedMs:Float):Void {
        if (_handlers.length == 0) return;
        var removeList:Array<ScriptHandler> = [];
        for (handler in _handlers.copy()) {
            handler.elapsedMs += elapsedMs;
            if (handler.elapsedMs < handler.intervalMs()) continue;
            handler.elapsedMs = 0;
            try {
                var result:Dynamic = Reflect.callMethod(null, handler.callback, [Api]);
                if (result == false) removeList.push(handler);
            } catch (e:Dynamic) {
                ApiLogger.error("Handlers", "Handler '" + handler.name + "' failed and was removed: " + Std.string(e));
                removeList.push(handler);
            }
        }
        for (handler in removeList) _handlers.remove(handler);
    }
}
