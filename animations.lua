lovebone = require "libraries.love-bone.lovebone"
require "constants"

function animate()
    -- local path = "assets/paneling_small.png"
    -- local imgData = love.image.newImageData(path)
    -- local path2 = "assets/grass.png"
    -- local imgData2 = love.image.newImageData(path2)

    local headHeight = TILE_SIZE / 3
    local headhWidth = TILE_SIZE / 3
    local torsoHeight = TILE_SIZE 
    local torsoWidth = TILE_SIZE / 2
    local legHeight = PLAYER_HEIGHT - torsoHeight - headHeight
    local legWidth = TILE_SIZE/ 3
    local handHeight = torsoHeight * 4 / 3
    local handWidth = legWidth
    local bones = {}
    local mySkeleton = lovebone.newSkeleton();

    -- Image data for each bone
    local torsoData = love.image.newImageData(torsoHeight, torsoWidth);
    torsoData:mapPixel(fullWhite)
    local headData = love.image.newImageData(headHeight, headhWidth);
    headData:mapPixel(fullWhite)

    -- Adding all the bones
    bones["torso"], torsoAttachment = addBone(mySkeleton, myActor, "torso", nil, {0, 0}, torsoWidth, torsoHeight)
    bones["head"], headAttachment = addBone(mySkeleton, myActor, "head", "torso", {-headHeight, 0}, headhWidth, headHeight)
    bones["leg1"], leg1Attachment = addBone(mySkeleton, myActor, "leg1", "torso", {torsoHeight, 0}, legWidth, legHeight)
    bones["leg2"], leg2Attachment = addBone(mySkeleton, myActor, "leg2", "torso", {torsoHeight, 0}, legWidth, legHeight)
    bones["hand1"], hand1Attachment = addBone(mySkeleton, myActor, "hand1", "torso", {0, 0}, handWidth, handHeight)
    bones["hand2"], hand2Attachment = addBone(mySkeleton, myActor, "hand2", "torso", {0, 0}, handWidth, handHeight)

    -- Adding animation frames
    local myAnimation = lovebone.newAnimation(mySkeleton)
    myAnimation:AddKeyFrame("head", 0, math.rad(0), nil, nil)
    myAnimation:AddKeyFrame("torso", 0, math.rad(0), nil, nil)
    myAnimation:AddKeyFrame("hand1", 0, math.rad(0), nil, nil)
    myAnimation:AddKeyFrame("hand2", 0, math.rad(0), nil, nil)
    myAnimation:AddKeyFrame("leg1", 0, math.rad(0), nil, nil)
    myAnimation:AddKeyFrame("leg2", 0, math.rad(0), nil, nil)

    myAnimation:AddKeyFrame("head", 1, math.rad(0), nil, nil)
    myAnimation:AddKeyFrame("torso", 1, math.rad(0), nil, nil)
    myAnimation:AddKeyFrame("hand1", 1, math.rad(45), nil, nil)
    myAnimation:AddKeyFrame("hand2", 1, math.rad(-45), nil, nil)
    myAnimation:AddKeyFrame("leg1", 1, math.rad(30), nil, nil)
    myAnimation:AddKeyFrame("leg2", 1, math.rad(-30), nil, nil)


    myAnimation:AddKeyFrame("head", 3, math.rad(0), nil, nil)
    myAnimation:AddKeyFrame("torso", 3, math.rad(0), nil, nil)
    myAnimation:AddKeyFrame("hand1", 3, math.rad(-45), nil, nil)
    myAnimation:AddKeyFrame("hand2", 3, math.rad(45), nil, nil)
    myAnimation:AddKeyFrame("leg1", 3, math.rad(-30), nil, nil)
    myAnimation:AddKeyFrame("leg2", 3, math.rad(30), nil, nil)

    myAnimation:AddKeyFrame("head", 4, math.rad(0), nil, nil)
    myAnimation:AddKeyFrame("torso", 4, math.rad(0), nil, nil)
    myAnimation:AddKeyFrame("hand1", 4, math.rad(0), nil, nil)
    myAnimation:AddKeyFrame("hand2", 4, math.rad(0), nil, nil)
    myAnimation:AddKeyFrame("leg1", 4, math.rad(0), nil, nil)
    myAnimation:AddKeyFrame("leg2", 4, math.rad(0), nil, nil)
    -- myAnimation:AddKeyFrame("torso", 1, math.rad(90), nil, nil)
    -- myAnimation:AddKeyFrame("head", 1, math.rad(0), nil, nil)   
    
    -- Creating the animator
    myActor = lovebone.newActor(mySkeleton)

    -- Setting all the attachments
    myActor:SetAttachment("torso", "torso", torsoAttachment)
    myActor:SetAttachment("head", "head", headAttachment)
    myActor:SetAttachment("leg1", "leg1", leg1Attachment)
    myActor:SetAttachment("leg2", "leg2", leg2Attachment)
    myActor:SetAttachment("hand1", "hand1", hand1Attachment)
    myActor:SetAttachment("hand2", "hand2", hand2Attachment)

    myActor:GetTransformer():SetTransform("player", myAnimation)
    myActor:GetTransformer():GetRoot().rotation = math.rad(90)
    myActor:GetTransformer():GetRoot().translation = {love.graphics.getWidth() / 2 , love.graphics.getHeight() / 2 - PLAYER_HEIGHT / 2 + headHeight}
end


function fullWhite(x, y, r, g, b, a) 
    return 255, 255, 255, 255
end

function updateAnimation()
    local x, y = player.body:getWorldCenter()
    myActor:GetTransformer():GetRoot().translation = {x, y}
end


function addBone(skeleton, actor, name, parent, translation, width, height)
    local bone = lovebone.newBone(parent, 1, translation, 0, {0,0}, {1, 1})
    skeleton:SetBone(name, bone)
    skeleton:Validate()

    local imgData = love.image.newImageData(height, width);
    imgData:mapPixel(fullWhite)
    local boneVisuals = lovebone.newVisual(imgData)
    local vw, vh = boneVisuals:GetDimensions();
    boneVisuals:SetOrigin(0, vh/2);
    local attachment = lovebone.newAttachment(boneVisuals)
    return bone, attachment
end