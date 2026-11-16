# Battleheim Lion Fury Lag Fix

Removes Dungeon Rampage Haxe's animated `ALLY_FRENZY` visual (buff ID `35093`, the `db_buff_battlefury` effect) before the game can create it. Nothing of that effect is loaded, so it cannot lag.

<!-- drh:show -->

The mod clears the buff's VFX entry once the game is ready, before the game loop starts. A buff view only asks for an effect when its VFX names one, so the animated symbol is never instantiated; the lag it caused is gone. What the character shows instead is the mod's `ON` option.

## Settings

The game's settings menu has a `Battleheim Lion Fury Lag Fix` section with one option, `ON`, on by default:

- `ON` (checked): the animation stays removed and the character gets a static `0xFF3300` tint at intensity `0.60` for the whole buff.
- `OFF` (unchecked): the animation stays removed and nothing is drawn on the character.

The distributed buff itself is untouched in both cases: its duration, damage, speed, and every other gameplay value stay as the game sends them.

Nothing is checked while no Battlefury is active: the per-frame tint update returns at once unless it is tracking a buff.

## Compatibility

DRH tags `17` and `18`, DRH Mod API `1.3`. This is an `extends` mod because it uses the game's internal buff and character-rendering classes; a game update may require an update to this mod.

<!-- /drh:show -->

## Installation

Install the mod ZIP from the DRH Launcher "Mods" page. To run a local source folder, use the launcher's `--run-mod <folder>` command.

## Publishing

The included release workflow drafts a GitHub release when a `v<version>` tag matching `mod.json` is pushed. Test the generated ZIP with DRH Launcher before publishing the release, then submit it to the mod index.

## Author and license

Made by **Qwettque**. MIT License; see [LICENSE](LICENSE).
