-- TODO:
--  Place Torches
--  Side Tunnels
--  Ore Vein Detection & Following
    -- Basically check what item you obtain when you mine & then check for surrounding ores
    -- that way you're not scanning every block, which takes time
    -- Use substring matching for resource names so you don't have to list all the ores & such
--  Fix dropItem function

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
local maxTorches = 64
local refuelWaitTime = 60
local minLayers = 30
local maxDistance = 400

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

-- Default position is bottom left of main layer
function mine2Layers(isMain)
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
                ttl.dig()
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
    elseif dist + twoLayerFuel >= fuel then
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
    -- This is inefficient but it'll work
    while ttl.getItemCount("minecraft:torch") < maxTorches do
        ttl.suck("forward",maxTorches)
        print("Waiting for torches")
        ttl.dropItem("minecraft:torch")
        sleep(refuelWaitTime)
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
    returnHome()
    assertCorrectLocation()
end

function run()
    local checkedIn, reachedMax
    while true do
        refuel()
        prepareTorches()
        moveToStart()
        while true do
            -- Just tunneling for now. Add stripmining later
            mine2Layers(true)
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