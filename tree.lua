-- Tree won't grow unless turtle is
-- at least one block away
WAIT_TIME = 20
-- Min fuel to chop down tallest
-- possible tree
MIN_FUEL = 4*31+4
if not turtle.detectDown() or turtle.detect() then
    error("Restart detected in wrong state. Aborting...")
else
    a, block = turtle.inspectDown()
    if not a or block.name ~= "minecraft:chest" then
        error("Restart detected in wrong state. Aborting...")
    end
end
while true do
    -- Refuel
    while turtle.getFuelLevel() < MIN_FUEL do
        print("Fuel level low. Attempting refuel.")
        turtle.select(16)
        turtle.turnRight()
        turtle.suck()
        turtle.refuel()
        turtle.turnLeft()
        turtle.select(1)
        sleep(WAIT_TIME)
    end
    -- Get saplings
    local saps = turtle.getItemCount(1)
    while saps < 4 do
        print("Saplings low. Attempting sapling pull")
        turtle.select(1)
        turtle.suckDown(60)
        saps = turtle.getItemCount(1)
        sleep(WAIT_TIME)
    end
    sleep(WAIT_TIME)
    print("Checking for tree")
    turtle.forward()
    a, block = turtle.inspect()
    if block.name == "minecraft:spruce_log" then
        print("Tree found")
        -- Cut down tree
        turtle.digUp()
        turtle.dig()
        turtle.forward()
        while turtle.detectUp() do
            turtle.dig()
            turtle.turnLeft()
            turtle.dig()
            turtle.forward()
            turtle.turnRight()
            turtle.dig()
            turtle.turnLeft()
            turtle.back()
            turtle.turnRight()
            turtle.digUp()
            turtle.up()
        end
        while turtle.down() do end
        -- Plant saplings
        print("Replanting")
        turtle.select(1)
        turtle.place()
        turtle.up()
        turtle.placeDown()
        turtle.turnLeft()
        turtle.forward()
        turtle.placeDown()
        turtle.turnRight()
        turtle.forward()
        turtle.placeDown()
        turtle.back()
        turtle.turnLeft()
        turtle.back()
        turtle.turnRight()
        turtle.back()
        turtle.down()
        turtle.back()
        turtle.turnRight()
        turtle.turnRight()
        -- Deposit items
        print("Depositing items")
        for i=2,16 do
            turtle.select(i)
            turtle.drop()
        end
        turtle.select(1)
        local slot1 = turtle.getItemDetail()
        if slot1 ~= nil and slot1.name ~= "minecraft:spruce_sapling" then
            turtle.drop()
        end
        turtle.turnRight()
        turtle.turnRight()
    else
        -- No tree yet. Wait
        print("Tree not found")
        turtle.back()
    end
end
