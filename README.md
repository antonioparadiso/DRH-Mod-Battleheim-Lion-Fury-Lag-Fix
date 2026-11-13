# Battleheim Lion Fury Lag Fix

Removes Dungeon Rampage Haxe's animated `ALLY_FRENZY` visual (buff ID `35093`) before the game can create it. The affected character always receives a static red tint instead.

<!-- drh:show -->

The mod clears the buff's VFX entry when the GameMaster tables load and again before the game loop starts. This prevents the original fire animation from being instantiated. The character receives a static `0xFF3300` tint at intensity `0.60` for the duration of the buff.

The mod has no color toggle: while installed, it always suppresses the animation and applies the static tint. The distributed buff remains active. Its duration, damage, speed, and other gameplay values are unchanged.

## Installation

Install the mod ZIP from the DRH Launcher "Mods" page. To run a local source folder, use the launcher's `--run-mod <folder>` command.

## Compatibility

DRH tag `17`, DRH Mod API `1.3`. This is an `extends` mod because it uses the game's internal buff and character-rendering classes; a game update may require an update to this mod.

## Publishing

The included release workflow drafts a GitHub release when a `v<version>` tag matching `mod.json` is pushed. Test the generated ZIP with DRH Launcher before publishing the release, then submit it to the mod index.

<!-- /drh:show -->

## Author and license

Made by **Qwettque**. MIT License; see [LICENSE](LICENSE).
