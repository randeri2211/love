local function Movement(maxSpeed, jumpHeight)
    local movement = {}

    movement.currentSpeed = maxSpeed or 0
    movement.maxSpeed = maxSpeed or 0
    movement.jumpHeight = jumpHeight or 0

    -- Base values, stats are applied on top of these
    movement.baseMaxSpeed = movement.maxSpeed
    movement.baseJumpHeight = movement.jumpHeight

    return movement
end

return Movement