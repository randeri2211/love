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

function Animateable:addBone(name, parent, layer, translation, width, height, imgData, visual)
    -- visual is a ready made love-bone visual(a part of a skin sheet), otherwise a width x height box is drawn
    self.bones[name] = lovebone.newBone(parent, layer, translation, 0, {0,0}, {1, 1})
    self.skeleton:SetBone(name, self.bones[name])
    self.skeleton:Validate()

    if visual == nil then
        if imgData == nil then
            imgData = love.image.newImageData(height, width);
            imgData:mapPixel(fullWhite)
        end
        visual = lovebone.newVisual(imgData)
        local vw, vh = visual:GetDimensions();
        visual:SetOrigin(0, vh/2);
    end
    self.attachments[name] = lovebone.newAttachment(visual)
end

function Animateable:SetAttachment(name)
    self.actor:SetAttachment(name, name, self.attachments[name])
end

function Animateable:newActor()
    self.actor = lovebone.newActor(self.skeleton)
end

-- Pixel colors for bone images(love.image mapPixel callbacks)
function fullWhite(x, y, r, g, b, a)
    return 255, 255, 255, 255
end

function fullBlue(x, y, r, g, b, a)
    return 0, 0, 255, 255
end

function fullRed(x, y, r, g, b, a)
    return 255, 0, 0, 255
end

return Animateable