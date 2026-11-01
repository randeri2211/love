local Animateable = require "animations.animateable"
local Animation = require "animations.animation"

-- The body plan the player and humanoid enemies share: a torso with a head, two legs and two hands
-- Head, torso and legs are white, the right hand blue and the left hand red so the sides are easy to tell apart
local Humanoid = {}

Humanoid.BONES = {"head", "torso", "right_hand", "left_hand", "right_leg", "left_leg"}


function Humanoid.build(width, height)
    -- Skeleton, attachments and actor sized to a width x height body, returns the rig and the hand length
    local headHeight = height / 6
    local headWidth = width / 3
    local torsoHeight = height / 2
    local torsoWidth = width / 2
    local legHeight = height - torsoHeight - headHeight
    local legWidth = width / 3
    local handHeight = torsoHeight * 4 / 3
    local handWidth = legWidth

    local anim = Animateable:new()

    local leftHandData = love.image.newImageData(handHeight, handWidth)
    leftHandData:mapPixel(fullRed)
    local rightHandData = love.image.newImageData(handHeight, handWidth)
    rightHandData:mapPixel(fullBlue)

    -- Bones, layers decide what draws in front(see face)
    anim:addBone("torso", nil, 2, {0, 0}, torsoWidth, torsoHeight)
    anim:addBone("head", "torso", 2, {-headHeight, 0}, headWidth, headHeight)
    anim:addBone("right_leg", "torso", 1, {torsoHeight, 0}, legWidth, legHeight)
    anim:addBone("left_leg", "torso", 3, {torsoHeight, 0}, legWidth, legHeight)
    anim:addBone("right_hand", "torso", 1, {0, 0}, handWidth, handHeight, rightHandData)
    anim:addBone("left_hand", "torso", 4, {0, 0}, handWidth, handHeight, leftHandData)

    -- The actor goes AFTER all the bones
    anim:newActor()
    for i, bone in ipairs(Humanoid.BONES) do
        anim:SetAttachment(bone)
    end

    -- The skeleton is built pointing right, turned so it stands up(bone angle 0 then points down)
    anim.actor:GetTransformer():GetRoot().rotation = math.rad(90)
    return anim, handHeight
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


function Humanoid.face(anim, direction)
    -- The near hand and leg draw in front, so the far ones go behind the torso
    if direction == "right" then
        anim.bones["right_hand"]:SetLayer(1)
        anim.bones["left_hand"]:SetLayer(4)
        anim.bones["right_leg"]:SetLayer(1)
        anim.bones["left_leg"]:SetLayer(3)
    elseif direction == "left" then
        anim.bones["right_hand"]:SetLayer(4)
        anim.bones["left_hand"]:SetLayer(1)
        anim.bones["right_leg"]:SetLayer(3)
        anim.bones["left_leg"]:SetLayer(1)
    end
end


function Humanoid.setAlpha(anim, alpha)
    -- See through body, used to blink while immune
    for i, bone in ipairs(Humanoid.BONES) do
        anim.attachments[bone]:SetColor(1, 1, 1, alpha)
    end
end


function Humanoid.place(anim, x, y, height)
    -- Hangs the rig from the top of the torso, a third of the body up from the center
    anim.actor:GetTransformer():GetRoot().translation = {x, y - height / 3}
end

return Humanoid
