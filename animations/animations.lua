lovebone = require "libraries.love-bone.lovebone"
require "constants"
require "animations.animateable"
Animation = {}

function Animation:new(skeleton)
    local animation = {}
    setmetatable(animation,self)
    self.__index = self

    animation.skeleton = skeleton
    animation.actor = lovebone.newActor(self.skeleton)
    animation.animation = lovebone.newAnimation(self.skeleton)
    animation.keyFrames = {}    

    return animation
end


function Animation:AddKeyFrame(name, keyTime, rotation, translation, scale)
    self.animation:AddKeyFrame(name, keyTime, rotation, translation, scale)
    local key = {name, keyTime}
    self.keyFrames[key] = {rotation, translation, scale}
end


function Animation:newAnimation()
    self.animation = lovebone.newAnimation(self.skeleton)
end
