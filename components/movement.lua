function Movement(maxSpeed, jumpHeight)
    local movement = {}

    movement.currentSpeed = maxSpeed or 0
    movement.maxSpeed = maxSpeed or 0
    movement.jumpHeight = jumpHeight or 0

    return movement
end