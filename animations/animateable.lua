local lovebone = require "libraries.love-bone.lovebone"

local Animateable = {}
function Animateable:new()
    local anim = {}
    setmetatable(anim,self)
    self.__index = self
    anim.skeleton = lovebone.newSkeleton()
    anim.bones = {}
    anim.attachments = {}
    return anim
end

function Animateable:addBone(name, parent, layer, translation, width, height, imgData)
    self.bones[name] = lovebone.newBone(parent, layer, translation, 0, {0,0}, {1, 1})
    self.skeleton:SetBone(name, self.bones[name])
    self.skeleton:Validate()

    if imgData == nil then 
        imgData = love.image.newImageData(height, width);
        imgData:mapPixel(fullWhite)
    end
    local boneVisuals = lovebone.newVisual(imgData)
    local vw, vh = boneVisuals:GetDimensions();
    boneVisuals:SetOrigin(0, vh/2);
    self.attachments[name] = lovebone.newAttachment(boneVisuals)
end

function Animateable:SetAttachment(name)
    self.actor:SetAttachment(name, name, self.attachments[name])
end

function Animateable:newActor()
    self.actor = lovebone.newActor(self.skeleton)
end

return Animateable