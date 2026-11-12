-- The mana effect: flowing mana drawn by a shader, shared by everything made of mana(the battery fill, network beams,
-- later mana spell effects), so it all looks like the same stuff
-- Drawn at screen resolution with soft gradients, a deliberate contrast with the pixel art that marks it as magic
-- (a style snapped to 2 pixel blocks with banded colors was tried, smooth was picked)
-- Drawn after the world light(see main.lua), mana glows at night
local ManaShader = {}

local SOURCE = [[
extern number time;
extern vec2 size;           // The drawn box in screen pixels
extern number fill;         // Fill mode: how full from the bottom(0 to 1), below 0 for beam mode
extern vec3 deep;
extern vec3 bright;

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
    float v = 0.0;
    float a = 0.5;
    for (int k = 0; k < 4; k++) {
        v += a * noise(p);
        p *= 2.03;
        a *= 0.5;
    }
    return v;
}

vec4 effect(vec4 color, Image tex, vec2 uv, vec2 screen) {
    vec2 px = uv * size;        // This pixel in the box
    vec2 p = px / 24.0;
    float v;
    float alpha = 1.0;
    if (fill >= 0.0) {
        // A liquid filling the box from the bottom, its surface waving
        float wave = sin(px.x * 0.22 + time * 2.6) * 1.2 + sin(px.x * 0.09 - time * 1.7) * 1.0;
        float depth = px.y - (size.y * (1.0 - fill) + wave);
        if (depth < 0.0 || fill <= 0.0) {
            return vec4(0.0);
        }
        float flow = fbm(p * 1.6 + vec2(time * 0.12, time * 0.35));
        v = fbm(p * 2.4 + flow * 1.8 - vec2(0.0, time * 0.25));
        v = v * 1.15 + (1.0 - smoothstep(0.0, 4.0, depth)) * 0.6;     // A bright line on the surface
    } else {
        // A beam along the box(uv.x runs along it), brightest in the middle, flowing from start to end
        float across = abs(uv.y - 0.5) * 2.0;
        float flow = fbm(vec2(p.x * 1.3 - time * 2.2, p.y * 2.0 + time * 0.3));
        v = (1.0 - across) * 0.8 + flow * 0.6 - across * 0.3;
        alpha = clamp((1.0 - across) * 1.6, 0.0, 1.0);
    }
    v = clamp(v, 0.0, 1.0);
    vec3 c = mix(deep, bright, clamp(v, 0.0, 1.0));
    return vec4(c, alpha) * color;
}
]]

local shader = nil
local pixel = nil   -- A white pixel, stretched over the box so the shader gets 0 to 1 coordinates across it


local function setup(w, h, fill)
    if shader == nil then
        shader = love.graphics.newShader(SOURCE)
        pixel = love.graphics.newImage(love.image.newImageData(1, 1, "rgba8", string.char(255, 255, 255, 255)))
    end
    shader:send("time", love.timer.getTime())
    shader:send("size", {w, h})
    shader:send("fill", fill)
    shader:send("deep", MANA_DEEP_COLOR)
    shader:send("bright", MANA_BRIGHT_COLOR)
    love.graphics.setShader(shader)
end


function ManaShader.fill(x, y, w, h, amount)
    -- Mana filling a box from the bottom, amount from 0(empty) to 1(full)
    love.graphics.push("all")
    setup(w, h, math.max(0, math.min(1, amount)))
    love.graphics.draw(pixel, x, y, 0, w, h)
    love.graphics.pop()
end


function ManaShader.beam(x1, y1, x2, y2, width)
    -- A beam of mana from one love point to another, flowing toward the second
    local length = math.sqrt((x2 - x1) ^ 2 + (y2 - y1) ^ 2)
    if length < 1 then
        return
    end
    love.graphics.push("all")
    setup(length, width, -1)
    love.graphics.draw(pixel, x1, y1, math.atan2(y2 - y1, x2 - x1), length, width, 0, 0.5)
    love.graphics.pop()
end


return ManaShader
