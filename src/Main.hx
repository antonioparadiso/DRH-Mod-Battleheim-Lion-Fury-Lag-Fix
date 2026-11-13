package mods.battleheim_lion_fury_lag_fix;

import actor.ActorView;
import actor.buffs.BuffGameObject;
import actor.buffs.DistributedBuffGameObject;
import gameMasterDictionary.GMBuff;
import mods.api.Context;
import mods.api.Mod;
import openfl.events.Event;

/**
 * Clears the ALLY_FRENZY (35093) VFX from the runtime GameMaster table before
 * a BuffView can create it. The distributed buff and its gameplay data remain
 * active, and the actor always receives a static red tint instead.
 */
class Main extends Mod {
	static inline var BATTLEFURY_ID:Int = 35093;
	static inline var TINT_COLOR:UInt = 0xFF3300;
	static inline var TINT_AMOUNT:Float = 0.60;

	var context:Context;
	var observed:Map<Int, DistributedBuffGameObject> = new Map();
	var applied:Map<Int, Dynamic> = new Map();
	var stopped:Bool = false;
	var failureLogged:Bool = false;

	override public function init(context:Context):Void {
		this.context = context;
		context.onTablesLoaded(disableBattlefuryAnimation);

		context.core.onObjectReady(function(object) {
			if (!Std.isOfType(object, DistributedBuffGameObject)) return;
			var buff:DistributedBuffGameObject = cast object;
			if (buff.type == BATTLEFURY_ID) observed.set(buff.id, buff);
		});
		context.core.onObjectGone(function(object) {
			if (!Std.isOfType(object, DistributedBuffGameObject)) return;
			var buff:DistributedBuffGameObject = cast object;
			if (buff.type == BATTLEFURY_ID) observed.remove(buff.id);
		});
		context.onFloorExit(function(_) clearAll());
		context.overlay.addEventListener(Event.EXIT_FRAME, update);
	}

	override public function ready(context:Context):Void {
		disableBattlefuryAnimation();
		context.log("loaded: Battleheim Lion Fury Lag Fix; Battlefury always uses a static red tint");
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

	function update(event:Event):Void {
		if (stopped || !context.core.alive) return;
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
		applied.remove(actorId);
	}

	function clearAll():Void {
		for (actorId in [for (id in applied.keys()) id]) clearActor(actorId);
		observed.clear();
	}

	override public function dispose():Void {
		stopped = true;
		if (context != null) context.overlay.removeEventListener(Event.EXIT_FRAME, update);
		clearAll();
		context = null;
	}
}
