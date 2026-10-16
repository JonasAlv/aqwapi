package com.aqwapi.scripting;

/**
 * One registered HScript callback. A callback returning false is removed,
 * matching Skua's IScriptHandlers contract.
 */
class ScriptHandler {
    public var name(default, null):String;
    public var ticks(default, null):Int;
    public var callback(default, null):Dynamic;
    public var elapsedMs:Float = 0;

    public function new(name:String, ticks:Int, callback:Dynamic) {
        this.name = name;
        this.ticks = ticks < 1 ? 1 : ticks;
        this.callback = callback;
    }

    public inline function intervalMs():Float {
        return ticks * 20.0;
    }
}
