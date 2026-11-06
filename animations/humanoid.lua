local lovebone = require "libraries.love-bone.lovebone"
local Animateable = require "animations.animateable"
local Animation = require "animations.animation"

-- The body plan the player and humanoid enemies share: a torso with a head, two legs and two hands
-- With a skin, every part is a piece of one skin sheet(assets/art*/skins/<skin>.png, laid out like SHEET)
-- Without one, head, torso and legs are white, the right hand blue and the left hand red
local Humanoid = {}

Humanoid.BONES = {"head", "torso", "right_hand", "left_hand", "right_leg", "left_leg"}

-- Skin sheet layout, the same for every humanoid skin(humanoid_template.png in the art folder shows it)
-- Written at the 16 pixel layout and made ART_UNIT times bigger for the art in use(a 32 pixel skin sheet is 58 x 26)
-- Parts are drawn upright facing right, pivot is the joint the part turns around
Humanoid.SHEET = {
    head = {x = 0, y = 0, w = 10, h = 10, pivot = {5, 10}},     -- Neck at the bottom
    torso = {x = 10, y = 0, w = 10, h = 12, pivot = {5, 0}},    -- Hangs from the neck
    arm = {x = 20, y = 0, w = 4, h = 13, pivot = {2, 1}},       -- Shoulder at the top
    leg = {x = 24, y = 0, w = 5, h = 9, pivot = {2.5, 0}},      -- Hip at the top
}
for part, p in pairs(Humanoid.SHEET) do
    p.x, p.y, p.w, p.h = p.x * ART_UNIT, p.y * ART_UNIT, p.w * ART_UNIT, p.h * ART_UNIT
    p.pivot = {p.pivot[1] * ART_UNIT, p.pivot[2] * ART_UNIT}
end
Humanoid.ART_SCALE = ART_SCREEN     -- Screen pixels per art pixel, the same as the block tiles
Humanoid.FAR_SHADE = 0.7    -- The far arm and leg are drawn darker, they are behind the body
Humanoid.LIE_LIFT = 8       -- Pixels a body lying down is raised, about half the torso width

local PART_OF = {head = "head", torso = "torso", right_hand = "arm", left_hand = "arm", right_leg = "leg", left_leg = "leg"}

local skins = {}    -- Skin sheet images by name, shared by every humanoid wearing that skin

local function skinImage(skin)
    if skins[skin] == nil then
        local image = love.graphics.newImage(ART_FOLDER .. "skins/" .. skin .. ".png")
        image:setFilter("nearest", "nearest")   -- Crisp art pixels like the tiles
        skins[skin] = image
    end
    return skins[skin]
end


local function skinVisual(image, part)
    -- One part of the sheet, turned so the upright art runs down the bone(bone angle 0 points down the body)
    local p = Humanoid.SHEET[part]
    local visual = lovebone.newVisual(image, p.x, p.y, p.w, p.h, image:getDimensions())
    visual:SetRotation(-math.pi / 2)
    visual:SetOrigin(p.pivot[1], p.pivot[2])
    visual:SetScale(Humanoid.ART_SCALE, Humanoid.ART_SCALE)
    return visual
end


local function buildSkinned(anim, skin)
    -- Bones placed from the sheet: the root is the neck, the hips are at the bottom of the torso
    local S = Humanoid.ART_SCALE
    local sheet = Humanoid.SHEET
    local image = skinImage(skin)
    local torsoLength = (sheet.torso.h - sheet.torso.pivot[2]) * S
    local shoulder = sheet.arm.pivot[2] * S
    local function visual(bone)
        return skinVisual(image, PART_OF[bone])
    end
    anim:addBone("torso", nil, 2, {0, 0}, nil, nil, nil, visual("torso"))
    anim:addBone("head", "torso", 2, {0, 0}, nil, nil, nil, visual("head"))
    anim:addBone("right_leg", "torso", 1, {torsoLength, 0}, nil, nil, nil, visual("right_leg"))
    anim:addBone("left_leg", "torso", 3, {torsoLength, 0}, nil, nil, nil, visual("left_leg"))
    anim:addBone("right_hand", "torso", 1, {shoulder, 0}, nil, nil, nil, visual("right_hand"))
    anim:addBone("left_hand", "torso", 4, {shoulder, 0}, nil, nil, nil, visual("left_hand"))

    anim.feetDrop = torsoLength + (sheet.leg.h - sheet.leg.pivot[2]) * S    -- Neck to feet
    anim.mirrorable = true
    return (sheet.arm.h - sheet.arm.pivot[2]) * S
end


local function buildPlain(anim, width, height)
    -- Colored boxes, sized from the body
    local headHeight = height / 6
    local headWidth = width / 3
    local torsoHeight = height / 2
    local torsoWidth = width / 2
    local legHeight = height - torsoHeight - headHeight
    local legWidth = width / 3
    local handHeight = torsoHeight * 4 / 3
    local handWidth = legWidth

    local leftHandData = love.image.newImageData(handHeight, handWidth)
    leftHandData:mapPixel(fullRed)
    local rightHandData = love.image.newImageData(handHeight, handWidth)
    rightHandData:mapPixel(fullBlue)

    anim:addBone("torso", nil, 2, {0, 0}, torsoWidth, torsoHeight)
    anim:addBone("head", "torso", 2, {-headHeight, 0}, headWidth, headHeight)
    anim:addBone("right_leg", "torso", 1, {torsoHeight, 0}, legWidth, legHeight)
    anim:addBone("left_leg", "torso", 3, {torsoHeight, 0}, legWidth, legHeight)
    anim:addBone("right_hand", "torso", 1, {0, 0}, handWidth, handHeight, rightHandData)
    anim:addBone("left_hand", "torso", 4, {0, 0}, handWidth, handHeight, leftHandData)

    anim.feetDrop = torsoHeight + legHeight
    return handHeight
end


function Humanoid.build(width, height, skin)
    -- Skeleton, attachments and actor for a width x height body, returns the rig and the hand length
    -- skin is a sheet name in assets/skins, without one the parts are colored boxes
    local anim = Animateable:new()
    local handLength
    if skin ~= nil then
        handLength = buildSkinned(anim, skin)
    else
        handLength = buildPlain(anim, width, height)
    end

    -- The actor goes AFTER all the bones
    anim:newActor()
    for i, bone in ipairs(Humanoid.BONES) do
        anim:SetAttachment(bone)
    end
    anim.shade = {}     -- Brightness per bone, the far limbs are darker(see face)
    anim.tint = {1, 1, 1}
    anim.alpha = 1

    -- The skeleton is built pointing right, turned so it stands up(bone angle 0 then points down)
    anim.actor:GetTransformer():GetRoot().rotation = math.rad(90)
    return anim, handLength
end


function Humanoid.walk(anim, cycleTime, frames)
    -- A looping animation from plain data: frames are {part of the cycle 0 to 1, {bone = degrees}}
    -- Bones a frame leaves out are at 0 for that frame
    local animation = Animation:new(anim.skeleton)
    -- Animation:new builds its animation before the skeleton is set, this one starts from the skeleton bind pose
    animation:newAnimation()
    for i, frame in ipairs(frames) do
        for j, bone in ipairs(Humanoid.BONES) do
            animation:AddKeyFrame(bone, frame[1] * cycleTime, math.rad(frame[2][bone] or 0), nil, nil)
        end
    end
    return animation
end


local function applyColors(anim)
    -- Far limb shade, tint(hit flash) and alpha(blink, fade) together
    local tint = anim.tint
    for i, bone in ipairs(Humanoid.BONES) do
        local shade = anim.shade[bone] or 1
        anim.attachments[bone]:SetColor(shade * tint[1], shade * tint[2], shade * tint[3], anim.alpha)
    end
end


function Humanoid.face(anim, direction)
    -- The near hand and leg draw in front and the far ones behind the torso, darker
    local near, far
    if direction == "right" then
        anim.bones["right_hand"]:SetLayer(1)
        anim.bones["left_hand"]:SetLayer(4)
        anim.bones["right_leg"]:SetLayer(1)
        anim.bones["left_leg"]:SetLayer(3)
        near, far = "left", "right"
    elseif direction == "left" then
        anim.bones["right_hand"]:SetLayer(4)
        anim.bones["left_hand"]:SetLayer(1)
        anim.bones["right_leg"]:SetLayer(3)
        anim.bones["left_leg"]:SetLayer(1)
        near, far = "right", "left"
    else
        return
    end
    anim.shade[far .. "_hand"], anim.shade[far .. "_leg"] = Humanoid.FAR_SHADE, Humanoid.FAR_SHADE
    anim.shade[near .. "_hand"], anim.shade[near .. "_leg"] = 1, 1
    applyColors(anim)

    -- Skin art is drawn facing right, mirrored around each bone to face left(the skeleton angles stay the same)
    if anim.mirrorable then
        local S = Humanoid.ART_SCALE
        local sx = direction == "left" and -S or S
        for i, bone in ipairs(Humanoid.BONES) do
            anim.attachments[bone]:GetVisual():SetScale(sx, S)
        end
    end
end


function Humanoid.setAlpha(anim, alpha)
    -- See through body, used to blink while immune
    if anim.alpha ~= alpha then
        anim.alpha = alpha
        applyColors(anim)
    end
end


function Humanoid.setTint(anim, r, g, b)
    -- Color multiplied over the whole body, like the red flash when hit
    local tint = anim.tint
    if tint[1] ~= r or tint[2] ~= g or tint[3] ~= b then
        anim.tint = {r, g, b}
        applyColors(anim)
    end
end


function Humanoid.tilt(anim, feetX, feetY, angle)
    -- Turns the whole body around its feet, angle 0 stands and 90 degrees lies with the head to the right
    -- Lying bodies are lifted a little so they rest on the ground instead of half in it
    local root = anim.actor:GetTransformer():GetRoot()
    root.rotation = math.pi / 2 + angle
    local lift = math.abs(math.sin(angle)) * Humanoid.LIE_LIFT
    root.translation = {feetX - math.cos(root.rotation) * anim.feetDrop, feetY - lift - math.sin(root.rotation) * anim.feetDrop}
end


function Humanoid.rootY(anim, y, height)
    -- Height of the neck(where the rig hangs from and the hands are) for a body centered at y, feet at the bottom
    return y + height / 2 - anim.feetDrop
end


function Humanoid.place(anim, x, y, height)
    -- Hangs the rig so its feet are at the bottom of the body
    anim.actor:GetTransformer():GetRoot().translation = {x, Humanoid.rootY(anim, y, height)}
end

return Humanoid
