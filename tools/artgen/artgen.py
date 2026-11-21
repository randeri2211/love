"""Game art from a theme, made by a local image model(FLUX.1-dev in ComfyUI, see tools/artgen/README.md)

Every tile of a sheet is redrawn from the tile the game has now: the current tile, scaled up, is the start of the image
(img2img, so the new tile keeps its shape and where things are), the theme prompt says how it should look, the pixel
art LoRA keeps it pixel art, and a reference image(optional) gives every tile the same style. Then the image is brought
back to the game's grid: shrunk to the tile size, every tile of the set put on one shared palette(that is what makes
them look like one set), and given the shape(transparency) of the current tile
The result is a whole art folder, assets/art32_<theme>, the game uses with --theme=<theme>

    python artgen.py themes/example.json                  every block tile
    python artgen.py themes/example.json --only grass,dirt only these(the rest come from the earlier run)
    python artgen.py themes/example.json --regen          make them again even when they were made before
    python artgen.py themes/example.json --post           only redo the palette and the sheet from the saved images
    python artgen.py themes/example.json --scratch        from noise instead of the current tile(text to image), into
                                                          <theme>_scratch, to compare
    python artgen.py themes/example.json --atlas          every tile in one image(a grid of them), into <theme>_atlas:
                                                          one style for the whole set, and one image instead of 41

Run it with ComfyUI's own Python(it has Pillow and numpy): D:/ComfyUI/ComfyUI_windows_portable/python_embeded/python.exe
"""
import argparse
import io
import json
import os
import re
import shutil
import sys
import time
import urllib.parse
import urllib.request
import uuid

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))     # ComfyUI's Python doesnt add the script's folder
from tiles import MAGICAL, describe

HERE = os.path.dirname(os.path.abspath(__file__))
GAME = os.path.abspath(os.path.join(HERE, "..", ".."))
ART_PIXELS = 32                     # The art the new set is made from and for(assets/art32)
UNIT = ART_PIXELS // 16             # Every sheet is laid out at 16 pixels times this
TILE, STEP = 16 * UNIT, 17 * UNIT   # A tile and the distance to the next one(a 1 pixel gap at 16)
WORK = 1024                         # The size the model draws at
# The atlas: the tiles in grids, ATLAS_CELL pixels a tile with ATLAS_GAP of plain grey between them(so the model keeps
# them apart), ATLAS_COLUMNS x ATLAS_ROWS a sheet(about the 1 megapixel the model is made for), as many sheets as it
# takes. A cell is 8 times the tile: the pixel art LoRA draws its pixels about 8 wide, so they land on the tile's grid
ATLAS_CELL, ATLAS_GAP, ATLAS_COLUMNS, ATLAS_ROWS = TILE * 8, 16, 4, 3
ORES = {"ore1", "ore2", "ore3", "ore4"}     # Nugget overlays drawn on stone in the game, the model sees them on stone
BACKGROUND = (128, 128, 128)        # Behind tiles that arent full squares, the model sees plain grey there


# Reading the game ------------------------------------------------------------------------------------------------

def tile_order():
    # The block tile names in sheet order, read from assets/assetLoader.lua so a new tile never needs adding here
    source = open(os.path.join(GAME, "assets", "assetLoader.lua"), encoding="utf-8").read()
    block = re.search(r"local TILE_ORDER = \{(.*?)\}", source, re.S).group(1)
    return re.findall(r'"(\w+)"', block)


def current_tile(sheet, index):
    return sheet.crop((index * STEP, 0, index * STEP + TILE, TILE)).convert("RGBA")


# ComfyUI ---------------------------------------------------------------------------------------------------------

class Comfy:
    def __init__(self, url):
        self.url = url.rstrip("/")
        self.client = str(uuid.uuid4())

    def call(self, path, data=None, raw=False):
        request = urllib.request.Request(self.url + path, data=data)
        if data is not None and not isinstance(data, bytes):
            request.data = json.dumps(data).encode()
            request.add_header("Content-Type", "application/json")
        with urllib.request.urlopen(request, timeout=600) as response:
            body = response.read()
        return body if raw else json.loads(body)

    def upload(self, image, name):
        # Sends an image to ComfyUI's input folder, returns the name to load it by
        buffer = io.BytesIO()
        image.save(buffer, "PNG")
        boundary = uuid.uuid4().hex
        body = (f"--{boundary}\r\nContent-Disposition: form-data; name=\"image\"; filename=\"{name}\"\r\n"
                f"Content-Type: image/png\r\n\r\n").encode() + buffer.getvalue() + \
               (f"\r\n--{boundary}\r\nContent-Disposition: form-data; name=\"overwrite\"\r\n\r\ntrue"
                f"\r\n--{boundary}--\r\n").encode()
        request = urllib.request.Request(self.url + "/upload/image", data=body)
        request.add_header("Content-Type", f"multipart/form-data; boundary={boundary}")
        with urllib.request.urlopen(request, timeout=120) as response:
            return json.loads(response.read())["name"]

    def run(self, graph):
        # Queues a graph and waits for its one saved image
        prompt_id = self.call("/prompt", {"prompt": graph, "client_id": self.client})["prompt_id"]
        while True:
            history = self.call("/history/" + prompt_id)
            if prompt_id in history:
                entry = history[prompt_id]
                if entry.get("status", {}).get("status_str") == "error":
                    raise RuntimeError(json.dumps(entry["status"], indent=1)[:2000])
                for output in entry["outputs"].values():
                    for image in output.get("images", []):
                        query = urllib.parse.urlencode(image)
                        return Image.open(io.BytesIO(self.call("/view?" + query, raw=True))).convert("RGB")
            time.sleep(0.5)


def graph(theme, image_name, prompt, seed, reference_name, scratch=False, areas=None, size=(WORK, WORK)):
    # The ComfyUI workflow(API format): Flux GGUF + pixel art LoRA, img2img from the current tile, Redux for the style
    g = {
        "unet": {"class_type": "UnetLoaderGGUF", "inputs": {"unet_name": theme["model"]}},
        "lora": {"class_type": "LoraLoaderModelOnly", "inputs": {"model": ["unet", 0], "lora_name": theme["lora"],
                 "strength_model": theme["lora_strength"]}},
        "clip": {"class_type": "DualCLIPLoader", "inputs": {"clip_name1": theme["clip_l"], "clip_name2": theme["t5"],
                 "type": "flux"}},
        "vae": {"class_type": "VAELoader", "inputs": {"vae_name": theme["vae"]}},
        "text": {"class_type": "CLIPTextEncode", "inputs": {"clip": ["clip", 0], "text": prompt}},
        "guide": {"class_type": "FluxGuidance", "inputs": {"conditioning": ["text", 0], "guidance": theme["guidance"]}},
        "empty": {"class_type": "ConditioningZeroOut", "inputs": {"conditioning": ["text", 0]}},
        "image": {"class_type": "LoadImage", "inputs": {"image": image_name}},
        "latent": {"class_type": "VAEEncode", "inputs": {"pixels": ["image", 0], "vae": ["vae", 0]}},
        "sample": {"class_type": "KSampler", "inputs": {"model": ["lora", 0], "seed": seed, "steps": theme["steps"],
                   "cfg": 1.0, "sampler_name": "euler", "scheduler": "simple", "positive": ["guide", 0],
                   "negative": ["empty", 0], "latent_image": ["latent", 0], "denoise": theme["denoise"]}},
        "decode": {"class_type": "VAEDecode", "inputs": {"samples": ["sample", 0], "vae": ["vae", 0]}},
        "save": {"class_type": "SaveImage", "inputs": {"images": ["decode", 0], "filename_prefix": "artgen"}},
    }
    if areas:
        # A prompt for every cell(its own subject in the theme's style) over the prompt for the whole sheet, so one
        # image keeps one style while every tile is told what it is
        last = "text"
        for k, (text, x, y, w, h) in enumerate(areas):
            g[f"areaText{k}"] = {"class_type": "CLIPTextEncode", "inputs": {"clip": ["clip", 0], "text": text}}
            g[f"area{k}"] = {"class_type": "ConditioningSetArea", "inputs": {"conditioning": [f"areaText{k}", 0],
                             "width": w, "height": h, "x": x, "y": y, "strength": theme.get("area_strength", 1.0)}}
            g[f"combine{k}"] = {"class_type": "ConditioningCombine", "inputs": {"conditioning_1": [last, 0],
                                "conditioning_2": [f"area{k}", 0]}}
            last = f"combine{k}"
        g["guide"]["inputs"]["conditioning"] = [last, 0]
    if scratch:
        # From noise: nothing of the current tile, only the prompt
        g["latent"] = {"class_type": "EmptySD3LatentImage", "inputs": {"width": size[0], "height": size[1], "batch_size": 1}}
        g["sample"]["inputs"]["denoise"] = 1.0
        del g["image"]
    if reference_name is not None:
        # The reference image's look goes into the conditioning, so every tile shares it
        g["visionModel"] = {"class_type": "CLIPVisionLoader", "inputs": {"clip_name": theme["clip_vision"]}}
        g["reference"] = {"class_type": "LoadImage", "inputs": {"image": reference_name}}
        g["vision"] = {"class_type": "CLIPVisionEncode", "inputs": {"clip_vision": ["visionModel", 0],
                       "image": ["reference", 0], "crop": "center"}}
        g["styleModel"] = {"class_type": "StyleModelLoader", "inputs": {"style_model_name": theme["style_model"]}}
        g["style"] = {"class_type": "StyleModelApply", "inputs": {"conditioning": ["guide", 0],
                      "style_model": ["styleModel", 0], "clip_vision_output": ["vision", 0],
                      "strength": theme["reference_strength"], "strength_type": "multiply"}}
        g["sample"]["inputs"]["positive"] = ["style", 0]
    return g


# Back to the game's grid -----------------------------------------------------------------------------------------

def start_image(tile):
    # The current tile scaled up with hard pixels onto plain grey, what the model starts from
    flat = Image.new("RGB", tile.size, BACKGROUND)
    flat.paste(tile, mask=tile.getchannel("A"))
    return flat.resize((WORK, WORK), Image.NEAREST)


def atlas_layout(count, columns=ATLAS_COLUMNS):
    # The size of one atlas sheet and the top left of every cell
    rows = (count + columns - 1) // columns
    step = ATLAS_CELL + ATLAS_GAP
    size = (columns * step + ATLAS_GAP, rows * step + ATLAS_GAP)
    spots = [(ATLAS_GAP + (i % columns) * step, ATLAS_GAP + (i // columns) * step) for i in range(count)]
    return size, spots


def atlas_start(tiles, unders, columns=ATLAS_COLUMNS):
    # Every current tile scaled up with hard pixels into its cell(over the tile under it, an ore over stone), plain
    # grey around them
    size, spots = atlas_layout(len(tiles), columns)
    atlas = Image.new("RGB", size, BACKGROUND)
    for tile, under, spot in zip(tiles, unders, spots):
        flat = Image.new("RGB", tile.size, BACKGROUND)
        if under is not None:
            flat.paste(under, mask=under.getchannel("A"))
        flat.paste(tile, mask=tile.getchannel("A"))
        atlas.paste(flat.resize((ATLAS_CELL, ATLAS_CELL), Image.NEAREST), spot)
    return atlas


def shrink(raw, block=None):
    # The model's image down to the tile size: every tile pixel the color most of the block it covers has(on a rough
    # palette first, so near colors count as one), no averaging, so no blended half pixels where its pixels straddle
    # block: model pixels an art pixel, by default the image is one tile(any size works then, a wide machine too)
    import numpy as np
    block = block or raw.size[0] // TILE
    w, h = raw.size[0] // block, raw.size[1] // block
    rough = raw.quantize(colors=64, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
    index = np.asarray(rough).reshape(h, block, w, block).transpose(0, 2, 1, 3).reshape(h, w, -1)
    colors = np.array(rough.getpalette()[:64 * 3], dtype=np.uint8).reshape(-1, 3)
    out = np.zeros((h, w, 3), dtype=np.uint8)
    for y in range(h):
        for x in range(w):
            out[y, x] = colors[np.bincount(index[y, x]).argmax()]
    return Image.fromarray(out, "RGB")


def palette_of(tiles, colors):
    # One palette for the whole set, from every tile together
    strip = Image.new("RGB", (TILE * len(tiles), TILE))
    for i, tile in enumerate(tiles):
        strip.paste(tile, (i * TILE, 0))
    return strip.quantize(colors=colors, method=Image.Quantize.MAXCOVERAGE, dither=Image.Dither.NONE)


def cut_out(small):
    # The shape of an object drawn from scratch: every pixel near the color of the corners(its plain background) is clear
    w, h = small.size
    corners = [small.getpixel(p) for p in ((0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1))]
    back = tuple(sum(c[k] for c in corners) // 4 for k in range(3))
    alpha = Image.new("L", small.size)
    alpha.putdata([0 if sum(abs(p[k] - back[k]) for k in range(3)) < 40 else 255 for p in small.getdata()])
    return alpha


def finish(small, current, palette, kind, scratch=False):
    # On the shared palette, with the current tile's shape(a full tile stays a full square), or for a tile drawn from
    # scratch the shape it was drawn with
    on_palette = small.quantize(palette=palette, dither=Image.Dither.NONE).convert("RGBA")
    if kind != "full":
        if scratch:
            on_palette.putalpha(cut_out(small))
        else:
            on_palette.putalpha(current.getchannel("A").point(lambda a: 255 if a >= 128 else 0))
    return on_palette


# The run ---------------------------------------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("theme", help="a theme file(see themes/example.json)")
    parser.add_argument("--only", help="comma separated tile names to make, the others are kept")
    parser.add_argument("--regen", action="store_true", help="make the tiles again even when they were made before")
    parser.add_argument("--post", action="store_true", help="dont generate, only redo the palette and the sheet")
    parser.add_argument("--scratch", action="store_true", help="from noise, not the current tile, into <theme>_scratch")
    parser.add_argument("--atlas", action="store_true", help="every tile in one image, into <theme>_atlas")
    parser.add_argument("--server", default="http://127.0.0.1:8188", help="where ComfyUI runs")
    args = parser.parse_args()

    theme = json.load(open(args.theme, encoding="utf-8"))
    name = theme["name"] + ("_scratch" if args.scratch else "") + ("_atlas" if args.atlas else "")
    work = os.path.join(HERE, "out", name)
    raw_dir = os.path.join(work, "raw")
    os.makedirs(raw_dir, exist_ok=True)

    sheet = Image.open(os.path.join(GAME, "assets", f"art{ART_PIXELS}", "blocks.png")).convert("RGBA")
    order = tile_order()
    only = set(args.only.split(",")) if args.only else None

    if args.atlas and not args.post:
        # A few sheets of tiles, each one image(one style, one seed and prompt for all), every tile with its own prompt
        # in its cell, then every cell cut out as that tile's image
        comfy = Comfy(args.server)
        stone = current_tile(sheet, order.index("stone1"))
        names = [n for n in order if not only or n in only]
        # From scratch every cell needs its own prompt(nothing else says what it is), fewer a sheet so they fit in VRAM
        columns, rows = (3, 2) if args.scratch else (ATLAS_COLUMNS, ATLAS_ROWS)
        per_sheet = columns * rows
        prompt = theme["prompt"].replace("{subject}", theme.get("atlas_subject",
            "a tilesheet of separate square game tiles in a grid on a plain grey background, every tile in its own square"))
        for first in range(0, len(names), per_sheet):
            batch = names[first:first + per_sheet]
            tiles = [current_tile(sheet, order.index(n)) for n in batch]
            start = atlas_start(tiles, [stone if n in ORES else None for n in batch], columns)
            size, spots = atlas_layout(len(batch), columns)
            areas = []
            for tile_name, (x, y) in zip(batch, spots):
                subject, kind = describe(tile_name)
                text = theme["prompt"].replace("{subject}", subject)
                text += ", " + (theme.get("full_hint", "") if kind == "full" else theme.get("shape_hint", ""))
                if tile_name in MAGICAL and theme.get("magic_hint"):
                    text += ", " + theme["magic_hint"]
                areas.append((text, x, y, ATLAS_CELL, ATLAS_CELL))
            sheet_name = f"atlas{first // per_sheet + 1}"
            upload = comfy.upload(start, f"artgen_{name}_{sheet_name}_start.png")
            started = time.time()
            if not theme.get("area_prompts", True) and not args.scratch:
                areas = None        # One prompt for the sheet(the per cell prompts cost memory and time)
            image = comfy.run(graph(theme, upload, prompt, theme["seed"], None, args.scratch, areas, size))
            image.save(os.path.join(work, sheet_name + ".png"))
            start.save(os.path.join(work, sheet_name + "_start.png"))
            for tile_name, (x, y) in zip(batch, spots):
                image.crop((x, y, x + ATLAS_CELL, y + ATLAS_CELL)).save(os.path.join(raw_dir, tile_name + ".png"))
            print(f"{sheet_name} {image.size[0]}x{image.size[1]}, {len(batch)} tiles in {time.time() - started:.1f} s")
    elif not args.post:
        comfy = Comfy(args.server)
        reference_name = None
        if theme.get("reference"):
            reference_name = comfy.upload(Image.open(os.path.join(HERE, theme["reference"])).convert("RGB"),
                                          f"artgen_{name}_reference.png")
        for i, tile_name in enumerate(order):
            path = os.path.join(raw_dir, tile_name + ".png")
            if (only and tile_name not in only) or (os.path.exists(path) and not args.regen and not only):
                continue
            subject, kind = describe(tile_name)
            prompt = theme["prompt"].replace("{subject}", subject)
            if tile_name in MAGICAL and theme.get("magic_hint"):
                prompt += ", " + theme["magic_hint"]     # Only magical things glow
            if kind == "full":
                prompt += ", " + theme.get("full_hint", "seamless tileable texture filling the whole square")
            else:
                prompt += ", " + theme.get("shape_hint", "single object centered on a plain grey background")
            upload = comfy.upload(start_image(current_tile(sheet, i)), f"artgen_{name}_{tile_name}.png")
            started = time.time()
            image = comfy.run(graph(theme, upload, prompt, theme["seed"] + i, reference_name, args.scratch))
            image.save(path)
            print(f"{tile_name:20s} {time.time() - started:5.1f} s  {prompt}")

    # Every tile made so far onto one palette, into a copy of the art folder
    made = [n for n in order if os.path.exists(os.path.join(raw_dir, n + ".png"))]
    if not made:
        sys.exit("Nothing made yet")
    small = {n: shrink(Image.open(os.path.join(raw_dir, n + ".png")).convert("RGB")) for n in made}
    palette = palette_of(list(small.values()), theme["palette_colors"])
    out_sheet = sheet.copy()
    preview = Image.new("RGBA", (len(made) * (TILE + 4) * 3, TILE * 3 * 2 + 12), (40, 40, 48, 255))
    for j, tile_name in enumerate(made):
        i = order.index(tile_name)
        current = current_tile(sheet, i)
        new = finish(small[tile_name], current, palette, describe(tile_name)[1], args.scratch)
        out_sheet.paste(Image.new("RGBA", (TILE, TILE)), (i * STEP, 0))
        out_sheet.paste(new, (i * STEP, 0))
        # Before over after, three times bigger
        x = j * (TILE + 4) * 3
        preview.alpha_composite(current.resize((TILE * 3, TILE * 3), Image.NEAREST), (x, 0))
        preview.alpha_composite(new.resize((TILE * 3, TILE * 3), Image.NEAREST), (x, TILE * 3 + 12))
    folder = os.path.join(GAME, "assets", f"art{ART_PIXELS}_{name}")
    if not os.path.exists(folder):
        shutil.copytree(os.path.join(GAME, "assets", f"art{ART_PIXELS}"), folder)
    out_sheet.save(os.path.join(folder, "blocks.png"))
    preview.save(os.path.join(work, "preview.png"))
    print(f"{len(made)} tiles into {folder}, before and after in {os.path.join(work, 'preview.png')}")


if __name__ == "__main__":
    main()
