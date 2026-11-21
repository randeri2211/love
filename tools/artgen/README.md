# artgen: game art from a theme

Redraws the block tilesheet in a theme with a local image model, FLUX.1-dev in ComfyUI on the GPU. Nothing goes online
once the models are downloaded.

## How it works
1. Every tile of `assets/art32/blocks.png` (names from `TILE_ORDER` in `assets/assetLoader.lua`) is scaled up and is the
   start of the image (img2img), so the new tile keeps the shape and layout of the current one.
2. The theme prompt (with the tile's subject from `tiles.py`), a pixel art LoRA, and optionally a reference image
   (Flux Redux) decide how it looks.
3. The image is shrunk back to 32 pixels, **every tile is put on one shared palette** (that is what makes them one set),
   and tiles that arent full squares get the transparency of the current tile.
4. The result is a copy of the art folder, `assets/art32_<theme>/`, with the new `blocks.png`. Start the game with
   `--theme=<theme>` to use it.

## Setup (done once)
- ComfyUI portable in `D:/ComfyUI/ComfyUI_windows_portable`, with the `ComfyUI-GGUF` custom node.
- Models in `ComfyUI/models`: `unet/flux1-dev-Q6_K.gguf` (city96), `clip/clip_l.safetensors` and
  `clip/t5xxl_fp8_e4m3fn.safetensors` (comfyanonymous), `vae/ae.safetensors`, `loras/ume_modern_pixelart.safetensors`
  (UmeAiRT, MIT), `style_models/flux1-redux-dev.safetensors` and `clip_vision/sigclip_vision_patch14_384.safetensors`.
- FLUX.1-dev is free for **non-commercial use only**. A commercial release needs other models (SDXL based) first.

## Use
Start ComfyUI (`run_nvidia_gpu.bat`), then with ComfyUI's Python:

    D:/ComfyUI/ComfyUI_windows_portable/python_embeded/python.exe tools/artgen/artgen.py tools/artgen/themes/example.json

- `--only grass,dirt` makes only those tiles again (to try a prompt on a few first)
- `--post` only redoes the palette and the sheet from the images already made (to try `palette_colors`)
- `--regen` makes every tile again

Each run writes `tools/artgen/out/<theme>/preview.png`, the current tiles over the new ones.

## A theme
`prompt` (with `{subject}` where the tile's subject goes), `full_hint` and `shape_hint` (added for full tiles and for
shaped ones), `reference` (an image in this folder whose style every tile takes, null for none) and how strongly,
`denoise` (how far from the current tile it may go: 0.5 close, 0.9 almost new), `guidance`, `steps`, `seed`,
`palette_colors` (fewer is more uniform), `lora_strength`, and the model file names.
