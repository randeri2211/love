# Magic Craft Dev (Stream Deck plugin)

Stream Deck keys for working on the game. The game listens on `127.0.0.1:27615` (`DEV_LINK_PORT` in `constants.lua`, `devLink.lua`), the plugin connects whenever the game is open.

## Keys

- **Game command**: sends a command to the running game, the key shows a check or a warning.

  | Command | Does |
  |---|---|
  | `art` | Reads every art file again (draw in LibreSprite, save, press). A sheet that changed size needs a restart |
  | `spawn Slime 3` | Enemies at the mouse (any name in `ENTITY_REGISTRY`) |
  | `give Torch 20` | Items into the inventory |
  | `time 22`, `time dawn` | Time of day: an hour or dawn, morning, noon, dusk, night, midnight |
  | `xp 500` | Experience |
  | `heal` | Full HP and mana |
  | `tp` | The player to the mouse |
  | `god`, `debug`, `onehit` | Toggle `DEBUG_GOD`, `DEBUG`, `DEBUG_ONE_HIT_BLOCKS` |
  | `save` | Saves the world |
  | `battery 60` | Fills the mana battery under the mouse to a percent |
  | `key j` | Presses a game key, so every key in `keys.lua` and the debug keys work |

- **Game readout**: shows FPS, position, enemy count, time, level, HP, mana, physics bodies or god mode. It can run a command when pressed (a God readout with `god` is a toggle that shows its state).
- **Launch game**: starts the game with the 32 or 16 pixel art (`--art32` / `--art16`).
- **Open art**: opens an art sheet in LibreSprite.

A new command goes in `COMMANDS` in `devLink.lua`, the plugin needs no change.

## Building

```
npm install
npm run build      # bundles src/ into the .sdPlugin/bin
npm run link       # once: links the plugin into the Stream Deck app, then restart the app
npm run restart    # after a build, reloads the plugin
```

Logs are in `com.randeri2211.magiccraft.sdPlugin/logs/`.
