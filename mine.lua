-- TODO:
-- More advanced vein detection
    -- Keep map of ores so as not to re-inspect
--  Side Tunnels

require("common")
local mainLayerWidth = 3
local mainLayerHeight = 3
local offshootWidth = 1
local offshootHeight = 2
local homeBase = {x=243,y=-57,z=154}
-- TODO: Refactor this for directional enumeration
local digAxis = "x"
-- 1 if digging positive along axis, -1 otherwise
local digPositive = 1
local REDNET_CHANNEL = "FAILURE"
local twoLayerFuel = 0
local minOpenSlots = 1
local trashables = {["minecraft:cobbled_deepslate"]=128}
local resourceNames = {"coal","iron","copper","gold","diamond","redstone","lapis"}
local maxTorches = 64
local refuelWaitTime = 60
local minLayers = 30
local maxDistance = 400
local minLightLevel = 5
local torchHeight = 1
local torchInterval
local lastPlacedTorch
local fuelBuffer = 100

function getDirEnum(axis,pos)
    if axis == "x" then
        if pos == 1 then
            return 0
        else
            return 2
        end
    else
        if pos == 1 then
            return 3
        else
            return 1
        end
    end
end

-- Takes a block or item name and checks if any resource name is a substring thereof
function isResource(itemName)
    if itemName == nil then return false end
    for i,name in pairs(resourceNames) do
        if string.find(itemName,name) then
            print("Resouorce " .. itemName .. " found with item " .. name)
            return true
        end
    end
    return false
end

function digAndCheck(direction)
    -- Select an empty slot. If you fail, return nil.
    if not ttl.selectItem(nil) then return nil end
    ttl.dig(direction)
    local item = turtle.getItemDetail()
    if item == nil then return nil end
    return item.name
end

local dirEnum = getDirEnum(digAxis,digPositive)

-- Make a bunch of variants and test their yields via /tick rate command
function refuel()
    -- Suck up as much fuel as you can
    while true do
        while turtle.suckUp() do end
        for i=1,16 do
            if turtle.getItemDetail(i) ~= nil then
                turtle.select(i)
                turtle.refuel()
            end
        end
        if turtle.getFuelLevel() >= twoLayerFuel*(minLayers/2)*2 then
            break
        else
            print("Waiting for fuel")
            sleep(refuelWaitTime)
        end
    end
end

function mineVeinSingle(a, block, direction)
    if a and isResource(block.name) then
        mineVein(direction)
    end
end

function isInTunnel(x,y,z) 
    if not (y >= homeBase.y and y < homeBase.y + mainLayerHeight) then
        return false
    end
    if digAxis == "x" and digPositive == 1 then
        return z >= homeBase.z and z < homeBase.z + mainLayerWidth
    elseif digAxis == "x" and digPositive == -1 then
        return z <= homeBase.z and z > homeBase.z - mainLayerWidth
    elseif digAxis == "z" and digPositive == 1 then
        return x <= homeBase.x and x > homeBase.x - mainLayerWidth
    elseif digAxis == "z" and digPositive == -1 then
        return x >= homeBase.x and x < homeBase.x + mainLayerWidth
    end
end

function mineVein(direction)
    -- TODO Implement
    -- Broken block was directly in front of turtle at start
    ttl.dig(direction)
    ttl.move(direction,true)
    local x, y, z = gps.locate()

    local aD, blockD = turtle.inspectDown()
    mineVeinSingle(aD,blockD,"down")

    local aU, blockU = turtle.inspectUp()
    mineVeinSingle(aU, blockU, "up")

    local aF, blockF = turtle.inspect()
    mineVeinSingle(aF, blockF, "forward")

    turtle.turnLeft()
    local aL, blockL = turtle.inspect()
    turtle.turnRight()
    mineVeinSingle(aL,blockL,"left")

    turtle.turnRight()
    local aR, blockR = turtle.inspect()
    turtle.turnLeft()
    mineVeinSingle(aR,blockR,"right")

    if not isInTunnel(x,y,z) then
        print(x,y,z,"is not in tunnel")
        turtle.turnLeft()
        turtle.turnLeft()
        local aB, blockB = turtle.inspect()
        turtle.turnLeft()
        turtle.turnLeft()
        mineVeinSingle(aB,blockB,"back")
    else
        print(x,y,z,"is in tunnel")
    end

    ttl.move(ttl.oppositeDir(direction),true)
end

-- Default position is bottom left of main layer
function mine2Layers(isMain)
    print("Mining 2 layers")
    local w = offshootWidth
    local h = offshootHeight
    if isMain then
        w = mainLayerWidth
        h = mainLayerHeight
    end
    for i=1,2 do
        -- When x % 2 == upMod, move up. 
        local upMod = 1
        if i == 2 and w % 2 == 1 then
            upMod = 0
        end
        for x=1,w do
            for y=1,h do
                local item = digAndCheck()
                if isResource(item) then
                    mineVein("forward")
                end
                ttl.consolidateSlot()
                if y ~= h then
                    if x % 2 == upMod then
                        ttl.up(true)
                    else
                        ttl.down(true)
                    end
                end
            end
            if x ~= w then
                if i == 1 then
                    turtle.turnRight()
                    ttl.forward(true)
                    turtle.turnLeft()
                else
                    turtle.turnLeft()
                    ttl.forward(true)
                    turtle.turnRight()
                end
            end
        end
        ttl.forward(true)
    end
end

function moveToStart()
    while turtle.forward() do end
end

-- For now just compatible with one central tunnel.
function returnHome()
    local x,y,z = gps.locate()
    while y > homeBase.y do
        ttl.down()
        x,y,z = gps.locate()
    end
    while y < homeBase.y do
        ttl.up()
        x,y,z = gps.locate()
    end
    ttl.back(true)
    x2,y2,z2 = gps.locate()
    ttl.forward(true)
    print(x,y,z,x2,y2,z2,ttl.findRotation(x2,z2,x,z))
    ttl.orient(ttl.findRotation(x2,z2,x,z),dirEnum)
    local targetValue
    local axisValue
    if digAxis == "x" then
        local otherDir = nil
        if (z > homeBase.z and digPositive == 1) or (z < homeBase.z and digPositive == -1) then
            turtle.turnLeft()
            otherDir = "right"
        elseif (z < homeBase.z and digPositive == 1) or (z > homeBase.z and digPositive == -1) then
            turtle.turnRight()
            otherDir = "left"
        end
        while z ~= homeBase.z do
            ttl.forward(true)
            x,y,z = gps.locate()
        end
        if otherDir ~= nil then
            ttl.turn(otherDir)
        end
        targetValue = homeBase.x
        axisValue = x
    else
        -- Violates DRY a little but it's fine
        local otherDir = nil
        if (x > homeBase.x and digPositive == 1) or (x < homeBase.x and digPositive == -1) then
            turtle.turnLeft()
            otherDir = "right"
        elseif (x < homeBase.x and digPositive == 1) or (x > homeBase.x and digPositive == -1) then
            turtle.turnRight()
            otherDir = "left"
        end
        while x ~= homeBase.x do
            ttl.forward(true)
        end
        if otherDir ~= nil then
            ttl.turn(otherDir)
        end
        targetValue = homeBase.z
        axisValue = z
    end
    x,y,z = gps.locate()
    print("Moving from " .. tostring(axisValue) .. " to " .. tostring(targetValue))
    while axisValue ~= targetValue do
        ttl.back()
        x,y,z = gps.locate()
        if digAxis == "x" then
            axisValue = x
        else
            axisValue = z
        end
    end
    assertCorrectLocation()
    turtle.turnRight()
    ttl.dropItem("minecraft:torch")
    turtle.turnLeft()
    while not ttl.dropAll("down") do
        print("Waiting for empty chest to drop into")
        sleep(refuelWaitTime)
    end
end

function checkIn()
    local x,y,z = gps.locate()
    local fuel = turtle.getFuelLevel()
    local dist = ttl.distance(x,y,z,homeBase.x,homeBase.y,homeBase.z)
    if dist > fuel then
        -- TODO: Give a rednet error with coordinates so a human knows where to pick up the turtle
        error("Stranded!")
    elseif dist > maxDistance then
        print("Traveled total max distance. Returning home")
        return false, true
    elseif dist + twoLayerFuel + 2 + (torchHeight-1)*torchInterval*2 + torchInterval*2 + (2 + 2*(torchHeight-1)) + fuelBuffer >= fuel then
        -- We don't have enough fuel to do another layer, so let's return home
        print("Low on fuel. Returning home.")
        return false, false
    elseif ttl.openSlotCount() < minOpenSlots then
        -- Inventory full. Returning home
        print("Inventory full. Returning home")
        return false, false
    end
    return true, false
end

function tossTrash()
    for item,count in pairs(trashables) do
        local currentCount = ttl.getItemCount(item)
        if currentCount > count then
            ttl.dropItem(item,currentCount-count)
        end
    end
end

function prepareTorches()
    ttl.turnRight()
    ttl.suck("forward",maxTorches)
    -- This is inefficient but it'll work
    while ttl.getItemCount("minecraft:torch") < maxTorches do
        print("Waiting for torches")
        ttl.dropItem("minecraft:torch")
        sleep(refuelWaitTime)
        ttl.suck("forward",maxTorches)
    end
    ttl.turnLeft()
end

function assertCorrectLocation()
    -- Assert proper positions. Eventually add compatibility to find its way back, but not now
    ttl.assertBlock("forward","none")
    ttl.assertBlock("right","minecraft:chest")
    ttl.assertBlock("back","minecraft:glass")
    ttl.assertBlock("down","minecraft:chest")
end

function setup()
    -- That's all for now. Later deal with side tunnels
    twoLayerFuel = ((mainLayerHeight*mainLayerWidth)-1)*2
    -- Torch has 14 light, decreases by 1 for each block away you are (city distance)
    -- They combine by taking the max.
    torchInterval = (13 - (minLightLevel + mainLayerWidth - 1 + torchHeight))*2
    if digAxis == "x" then
        lastPlacedTorch = homeBase.x
    else
        lastPlacedTorch = homeBase.z
    end
    returnHome()
    assertCorrectLocation()
end

function findLastTorch()
    local dist = 0
    for i=1,torchInterval do
        print("Checking for torch step " .. tostring(i))
        for y=1,torchHeight-1 do
            ttl.up(false)
        end
        local a, block = turtle.inspectUp()
        for y=1,torchHeight-1 do
            ttl.down(true)
        end
        local x, y, z = gps.locate()
        if ttl.distance(x,y,z,homeBase.x,homeBase.y,homeBase.z) == 0 then
            for i2=1,i-1 do
                print("Moving back step " .. tostring(i2))
                ttl.forward(true)
            end
            return
        end
        if a and block.name == "minecraft:wall_torch" then
            if digAxis == "x" then
                lastPlacedTorch = x
            else
                lastPlacedTorch = z
            end
            for i2=1,i-1 do
                print("Moving back step " .. tostring(i2))
                ttl.forward(true)
            end
            return
        end
        ttl.back(true)
        dist = i
    end
    for i2=1,dist do
        print("Moving back step " .. tostring(i2))
        ttl.forward(true)
    end
end

function placeTorchIfNeeded()
    local x, y, z = gps.locate()
    local axis
    if digAxis == "x" then
        axis = x
    else
        axis = z
    end
    if math.abs(axis - lastPlacedTorch) >= torchInterval then
        ttl.selectItem("minecraft:torch")
        for i=1,torchHeight-1 do
            ttl.up(true)
        end
        ttl.back(true)
        turtle.placeUp()
        ttl.forward(true)
        for i=1,torchHeight-1 do
            ttl.down(true)
        end
        lastPlacedTorch = axis
    end
end

function run()
    local checkedIn, reachedMax
    while true do
        refuel()
        prepareTorches()
        moveToStart()
        findLastTorch()
        while true do
            -- Just tunneling for now. Add stripmining later
            mine2Layers(true)
            placeTorchIfNeeded()
            tossTrash()
            checkedIn, reachedMax = checkIn()
            if not checkedIn then
                returnHome()
                break
            end
        end
        if reachedMax then
            break
        end
    end
    print("Finished maximum distance")
end

setup()
run()