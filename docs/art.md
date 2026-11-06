# Art

The game's pixel art lives in two folders with the same files and the same layout:

- `assets/art32/` is the art in use: 32 art pixels to a tile, drawn 1 screen pixel per art pixel.
- `assets/art16/` is the 16 pixel art kept to compare against (drawn at 2x, it looks the same size in game).

`ART_PIXELS` in `constants.lua` picks the folder (32 or 16), restart the game after changing it.
The 32 folder started as the 16 art with every pixel doubled, so it looks identical until something is redrawn.
Keep one pixel size for everything that is drawn at once: 16 art next to 32 art stands out.

The UI font (`assets/pixelFont.png`) is not part of this, it stays the same in both.

## Layouts

Every number below is for the 32 folder, the 16 folder is half of each.

| File | Layout |
|---|---|
| `blocks.png` | Tiles of 32 x 32 in one row, 34 pixels apart (a 2 pixel gap). The order is `TILE_ORDER` in `assets/assetLoader.lua`: a new tile goes at the end of the row and its name at the end of the list. `slab` uses only the lower half of its tile |
| `items.png` | Item icons laid out like the tiles, the order is the icon list in `assets/assetLoader.lua`. Drawn light and grey: the game tints them by the item |
| `skins/<name>.png` | One sheet of 58 x 26 per humanoid (player, zombies, skeleton, mage). `humanoid_template.png` shows where the head (20 x 20), torso (20 x 24), arm (8 x 26) and leg (10 x 18) go. Parts face right |
| `creatures/slime.png` | Cells of 36 x 26, 2 pixels apart. Columns: idle, squash, jump. Rows: plains, desert, snow. A frame sits at the bottom middle of its cell, faces right (it is turned to face the player) |
| `creatures/bat.png` | Cells of 36 x 18, 2 pixels apart: wings up, level, down. The body row is at 8.5, 4.5 and 4.5 pixels from the top (it lines the frames up while flapping) |
| `creatures/bow.png` | Cells of 24 x 22, 2 pixels apart: at rest, half drawn, fully drawn. Points right, held at pixel 18, 10 |

Slimes are drawn bigger than their art for the medium (1.5x) and big (2x) sizes, small slimes are their art size.

## In LibreSprite

- Open a sheet, set the grid to the cell size plus the gap (34 x 34 for `blocks.png`) to see the cells.
- Keep the gaps empty and the cells in place, the game finds each picture by its position.
- To add a new humanoid skin, copy `humanoid_template.png`, paint over it and name the skin in the enemy's file.
