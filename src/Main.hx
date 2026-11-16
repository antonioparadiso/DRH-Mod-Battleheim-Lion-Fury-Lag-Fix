package mods.battleheim_lion_fury_lag_fix;

import actor.ActorView;
import actor.buffs.BuffGameObject;
import actor.buffs.DistributedBuffGameObject;
import gameMasterDictionary.GMBuff;
import mods.api.Context;
import mods.api.Mod;
import mods.api.settings.Flag;
import openfl.events.Event;

/**
 * Clears the ALLY_FRENZY (35093) VFX from the runtime GameMaster table in
 * `ready`, before the game loop starts. A BuffView only asks for the effect
 * when `VFX` names one, so the laggy symbol is never loaded.
 *
 * The mod's "ON" option picks what the character shows instead: the static red
 * tint (checked, the default) or nothing at all (unchecked).
 */
class Main extends Mod {
	static inline var BATTLEFURY_ID:Int = 35093;
	static inline var TINT_COLOR:UInt = 0xFF3300;
	static inline var TINT_AMOUNT:Float = 0.60;

	var context:Context;
	var enabled:Flag;
	var observed:Map<Int, DistributedBuffGameObject> = new Map();
	var applied:Map<Int, Dynamic> = new Map();
	var observedCount:Int = 0;
	var appliedCount:Int = 0;
	var stopped:Bool = false;
	var failureLogged:Bool = false;

	override public function init(context:Context):Void {
		this.context = context;

		// Settings > MODS (ADVANCED before DRH 18) > Battleheim Lion Fury Lag Fix.
		enabled = context.settings.flag("enabled", "ON", "Off: animation completely removed.", true);
		enabled.onChange(onEnabledChanged);

		context.core.onObjectReady(function(object) {
			if (!Std.isOfType(object, DistributedBuffGameObject)) return;
			var buff:DistributedBuffGameObject = cast object;
			if (buff.type != BATTLEFURY_ID) return;
			if (!observed.exists(buff.id)) observedCount++;
			observed.set(buff.id, buff);
		});
		context.core.onObjectGone(function(object) {
			if (!Std.isOfType(object, DistributedBuffGameObject)) return;
			var buff:DistributedBuffGameObject = cast object;
			if (buff.type == BATTLEFURY_ID && observed.remove(buff.id)) observedCount--;
		});
		context.onFloorExit(function(_) clearAll());
		context.overlay.addEventListener(Event.EXIT_FRAME, update);
	}

	override public function ready(context:Context):Void {
		disableBattlefuryAnimation();
		context.log("loaded: Battleheim Lion Fury Lag Fix; static red tint " + (enabled.value ? "on" : "off (animation removed, nothing drawn)"));
	}

	function disableBattlefuryAnimation():Void {
		try {
			var gameBuff:GMBuff = cast context.core.facade.gameMaster.buffById.itemFor(BATTLEFURY_ID);
			if (gameBuff == null) throw "GameMaster buff 35093 was not found";
			gameBuff.VFX = "";
			context.log("removed ALLY_FRENZY VFX before buff visuals are created");
		} catch (error:Dynamic) {
			context.log("could not remove ALLY_FRENZY VFX from GameMaster: " + Std.string(error));
		}
	}

	function onEnabledChanged(value:Bool):Void {
		if (context == null) return;
		if (value) {
			context.log("static red tint on");
			return;
		}
		context.log("static red tint off: the animation stays removed and nothing is drawn");
		clearTints();
	}

	function update(event:Event):Void {
		if (stopped || !context.core.alive) return;
		// Off: no tint to keep, and nothing the pass would do.
		if (!enabled.value) return;
		// Nothing tracked: skip the map and array this frame would allocate.
		if (observedCount == 0 && appliedCount == 0) return;
		var present:Map<Int, Bool> = new Map();
		try {
			for (id in observed.keys()) {
				var distributed = observed.get(id);
				if (distributed == null || distributed.isDestroyed || distributed.type != BATTLEFURY_ID) continue;

				var actorId:Int = Std.int(Reflect.field(distributed, "mEffectedActor"));
				present.set(actorId, true);
				// postGenerate links the network buff to its BuffHandler. Wait for
				// that link and the local BuffGameObject before touching its visual.
				var handler:Dynamic = Reflect.field(distributed, "buffHandler");
				if (handler == null) continue;
				var buffs:Dynamic = Reflect.field(handler, "mBuffs");
				if (buffs == null) continue;
				var itemFor:Dynamic = Reflect.field(buffs, "itemFor");
				if (itemFor == null) continue;
				var gameBuff:BuffGameObject = cast Reflect.callMethod(buffs, itemFor, [BATTLEFURY_ID]);
				if (gameBuff == null) continue;
				var actorView:ActorView = gameBuff.actorGameObject == null ? null : gameBuff.actorGameObject.actorView;
				if (actorView == null) continue;

				var previous:Dynamic = applied.get(actorId);
				if (previous != null && previous.gameBuff == gameBuff && previous.view == actorView) {
					setActorTint(actorId);
					continue;
				}
				if (previous != null) clearActor(actorId);

				// GameMaster.VFX was cleared before gameplay, so this buff view
				// never creates the animated effect. Keep the static tint active.
				applied.set(actorId, {view: actorView, gameBuff: gameBuff, tinted: false});
				appliedCount++;
				setActorTint(actorId);
			}

			for (actorId in [for (id in applied.keys()) id]) {
				if (!present.exists(actorId)) clearActor(actorId);
			}
			failureLogged = false;
		} catch (error:Dynamic) {
			if (!failureLogged) context.log("Battlefury visual update failed: " + Std.string(error));
			failureLogged = true;
		}
	}

	function setActorTint(actorId:Int):Void {
		var record:Dynamic = applied.get(actorId);
		if (record == null || record.view == null) return;
		if (record.tinted && tintStateMatches(record.view)) return;
		record.view.applyStatusTint(TINT_COLOR, TINT_AMOUNT);
		record.tinted = true;
	}

	function tintStateMatches(view:ActorView):Bool {
		if (Reflect.field(view, "mStatusTintColor") != TINT_COLOR) return false;
		var amount:Float = Reflect.field(view, "mStatusTintAmount");
		if (Math.abs(amount - TINT_AMOUNT) >= 0.001) return false;
		var body:Dynamic = Reflect.getProperty(view, "bodyAnimRenderer");
		var weapon:Dynamic = Reflect.getProperty(view, "currentWeapon");
		var weaponRenderer:Dynamic = weapon == null ? null : Reflect.getProperty(weapon, "weaponRenderer");
		return rendererTintMatches(body) && rendererTintMatches(weaponRenderer);
	}

	function rendererTintMatches(renderer:Dynamic):Bool {
		if (renderer == null) return true;
		if (Reflect.field(renderer, "mStatusTintColor") != TINT_COLOR) return false;
		var amount:Float = Reflect.field(renderer, "mStatusTintAmount");
		return Math.abs(amount - TINT_AMOUNT) < 0.001;
	}

	function clearActor(actorId:Int):Void {
		var record:Dynamic = applied.get(actorId);
		try {
			if (record != null && record.view != null && record.tinted) {
				var clearTint:Dynamic = Reflect.field(record.view, "clearStatusTint");
				if (clearTint != null) Reflect.callMethod(record.view, clearTint, []);
			}
		} catch (error:Dynamic) {
			if (context != null) context.log("could not clear Battlefury tint: " + Std.string(error));
		}
		if (applied.remove(actorId)) appliedCount--;
	}

	function clearTints():Void {
		for (actorId in [for (id in applied.keys()) id]) clearActor(actorId);
		appliedCount = 0;
	}

	function clearAll():Void {
		clearTints();
		observed.clear();
		observedCount = 0;
	}

	override public function dispose():Void {
		stopped = true;
		if (context != null) context.overlay.removeEventListener(Event.EXIT_FRAME, update);
		clearAll();
		context = null;
	}
}
