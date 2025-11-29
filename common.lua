-- TODO: Add optional error logging to a rednet or web server so we can track down failed turtles

-- Higher-order function. Attempts a specified number of times, then errors if all fail.
function failsafe(func,waitTime,maxAttempts,errorMsg,failureFunc)
    local attempts = 0
    while attempts < maxAttempts do
        if func() then return true end
        attempts = attempts + 1
        if waitTime > 0 then
            sleep(waitTime) 
        end
        if failureFunc ~= nil then
            failureFunc()
        end
    end
    error(errorMsg)
    return false
end

ttl = {}

function ttl.up(breakOnFail)
    local failFunc = nil
    if breakOnFail then
        failFunc = turtle.digUp
    end
    failsafe(turtle.up,1,10,"Failed to move turtle up",failFunc)
end

function ttl.down(breakOnFail)
    local failFunc = nil
    if breakOnFail then
        failFunc = turtle.digDown
    end
    failsafe(turtle.down,1,10,"Failed to move turtle down",failFunc)
end

function ttl.forward(breakOnFail)
    local failFunc = nil
    if breakOnFail then
        failFunc = turtle.dig
    end
    failsafe(turtle.forward,1,10,"Failed to move turtle forward",failFunc)
end

function digBack()
    turtle.turnLeft()
    turtle.turnLeft()
    turtle.dig()
    turtle.turnLeft()
    turtle.turnLeft()
end

function ttl.back(breakOnFail)
    local failFunc = nil
    if breakOnFail then
        failFunc = digBack
    end
    failsafe(turtle.back,1,10,"Failed to move turtle back",failFunc)
end

function ttl.digUp()
    if not turtle.digUp() then return false end
    -- In case of gravel or falling item
    while turtle.digUp() do end
    return true
end

function ttl.digDown()
    if not turtle.digDown() then return false end
    -- In case of gravel or falling item
    while turtle.digDown() do end
    return true
end

function ttl.dig(direction)
    if direction == "up" then
        return ttl.digUp()
    end
    if direction == "down" then
        return ttl.digDown()
    end
    if not turtle.dig() then return false end
    -- In case of gravel or falling item
    while turtle.dig() do end
    return true
end

-- Not necessary, but useful if you're used to typing ttl instead of turtle
function ttl.turnLeft()
    turtle.turnLeft()
end

function ttl.turnRight()
    turtle.turnRight()
end

function ttl.turn(direction)
    if direction == "left" then
        turtle.turnLeft()
        return true
    elseif direction == "right" then
        turtle.turnRight()
        return true
    end
    error("Invalid direction. Should be left or right")
end

function ttl.selectItem(itemName)
    for i=1,16 do
        local detail = turtle.getItemDetail(i)
        if (itemName == nil and detail == nil) or (detail ~= nil and detail.name == itemName) then
            turtle.select(i)
            return i
        end
    end
    return -1
end

-- Gets "city block" distance between two points
-- This is the minimum fuel required to move between them
function ttl.distance(x1,y1,z1,x2,y2,z2)
    return math.abs(x1-x2)+math.abs(y1-y2)+math.abs(z1-z2)
end

function ttl.openSlotCount()
    local count = 0
    for i=1,16 do
        local detail = turtle.getItemDetail(i)
        if detail == nil then
            count=count+1
        end
    end
    return count
end

-- Can leave direction or count as nil. Default is forward and whole stack
function ttl.drop(direction,count)
    if direction == "up" then
        return turtle.dropUp(count)
    elseif direction == "down" then
        return turtle.dropDown(count)
    else
        return turtle.drop(count)
    end
end

-- Direction is optional
function ttl.dropItem(itemName,maxCount,direction)
    local count = maxCount
    for i=1,16 do
        local detail = turtle.getItemDetail(i)
        if detail ~= nil and itemName == detail.name then
            turtle.select(i)
            if count ~= nil and detail.count > count then
                ttl.drop(direction,count)
                break
            else
                ttl.drop(direction)
                if count ~= nil then
                    count = count - detail.count
                end
            end
        end
    end
end

function ttl.dropAll(direction)
    for i=1,16 do
        ttl.select(i)
        local success, res = ttl.drop(direction)
        if not success and res ~= "No items to drop" then
            return false
        end
    end
    return true
end

function ttl.getItemCount(itemName)
    local count = 0
    for i=1,16 do
        local detail = turtle.getItemDetail(i)
        if detail ~= nil and detail.name == itemName then
            count = count + detail.count
        end
    end
    return count
end

function doSuck(direction,count)
    if direction == "up" then
        return turtle.suckUp(count)
    elseif direction == "down" then
        return turtle.suckDown(count)
    else
        return turtle.suck(count)
    end
end

function ttl.suck(direction,count)
    local csf = count
    while csf ~= nil and csf > 64 do
        if not doSuck(direction,count) then return false end
        csf = csf - 64
    end
    return doSuck(direction,csf)
end

-- Asserts block in given direction has name.
-- Pass "any" if there simply must be a block
-- Pass "none" if there must *not* be a block
function ttl.assertBlock(direction,name)
    if direction == "back" then
        turtle.turnLeft()
        turtle.turnLeft()
    elseif direction == "right" then
        turtle.turnRight()
    elseif direction == "left" then
        turtle.turnLeft()
    end

    local exists, block
    if direction == "up" then
        exists, block = turtle.inspectUp()
    elseif direction == "down" then
        exists, block = turtle.inspectDown()
    else
        exists, block = turtle.inspect()
    end
    
    if name == "any" then
        assert(exists)
    elseif name == "none" then
        assert(not exists)
    else
        assert(exists and block.name == name)
    end

    if direction == "back" then
        turtle.turnLeft()
        turtle.turnLeft()
    elseif direction == "right" then
        turtle.turnLeft()
    elseif direction == "left" then
        turtle.turnRight()
    end
end

function ttl.select(i)
    return turtle.select(i)
end

-- Stack all items that are stackable. TODO
function ttl.consolidateItems()
    local itemDict = {}
end

-- Takes 0, 1, 2, or 3
function ttl.orient(rotation, destRotation)
    local rot = rotation
    -- TODO use right turns when more efficient
    while rot ~= destRotation do
        turtle.turnLeft()
        rot = (rot + 1) % 4
    end
end

-- +x: 0, -z: 1, -x: 2, +z: 3
-- Assumes second position is one block in front of first position
-- It is left to the user to get both locations as it could require breaking blocks
function ttl.findRotation(x1,z1,x2,z2)
    if x2 > x1 then return 0 end
    if z2 < z1 then return 1 end
    if x1 < x2 then return 2 end
    if z2 > z1 then return 3 end
    error("Bad Rotation Arguments: " .. tostring(x1) .. " " .. tostring(z1) .. " " .. tostring(x2) .. " " .. tostring(z2))
end