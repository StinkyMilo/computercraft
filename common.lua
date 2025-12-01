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

function ttl.oppositeDir(direction)
    if direction == "left" then return "right" end
    if direction == "right" then return "left" end
    if direction == "up" then return "down" end
    if direction == "down" then return "up" end
    if direction == "forward" then return "back" end
    if direction == "back" then return "forward" end
    error("Invalid direction")
end

function ttl.forward(breakOnFail)
    local failFunc = nil
    if breakOnFail then
        failFunc = turtle.dig
    end
    failsafe(turtle.forward,1,10,"Failed to move turtle forward",failFunc)
end

function ttl.move(direction,breakOnFail)
    if direction == "forward" then
        return ttl.forward(breakOnFail)
    end
    if direction == "back" then
        return ttl.back(breakOnFail)
    end
    if direction == "up" then
        return ttl.up(breakOnFail)
    end
    if direction == "down" then
        return ttl.down(breakOnFail)
    end
    if direction == "left" then
        turtle.turnLeft()
        local val = ttl.forward(breakOnFail)
        turtle.turnRight()
        return val
    end
    if direction == "right" then
        turtle.turnRight()
        local val = ttl.forward(breakOnFail)
        turtle.turnLeft()
        return val
    end
    error("Invalid direction " .. tostring(direction))
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
    -- TODO: Make more efficient by mapping the space and not testing directions you already tested
    -- with different ore.
    -- TODO: Replace all blocks broken with fodder if possible
    if direction == "up" then
        return ttl.digUp()
    end
    if direction == "down" then
        return ttl.digDown()
    end
    -- Not ideal if you're going left for a while,
    -- but if you're digging one block and maintaining orientation,
    -- it should be fine.
    if direction == "right" then
        turtle.turnRight()
        local result = ttl.dig()
        turtle.turnLeft()
        return result
    end
    if direction == "left" then
        turtle.turnLeft()
        local result = ttl.dig()
        turtle.turnRight()
        return result
    end
    if direction == "back" then
        turtle.turnLeft()
        turtle.turnLeft()
        local result = ttl.dig()
        turtle.turnLeft()
        turtle.turnLeft()
        return result
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

function ttl.consolidateSlot(slot)
    if slot == nil then
        slot = turtle.getSelectedSlot()
    end
    local targetDetail = turtle.getItemDetail(slot)
    if targetDetail == nil then
        return
    end
    local totalCount = targetDetail.count
    for i=1,16 do
        if i ~= slot then
            local detail = turtle.getItemDetail(i)
            local space = turtle.getItemSpace(i)
            if detail ~= nil and detail.name == targetDetail.name and space > 0 then
                turtle.select(slot)
                turtle.transferTo(i,space)
                totalCount = totalCount - math.min(detail.count,space)
            end
            if totalCount <= 0 then break end
        end
    end
end

-- Stack all items that are stackable. TODO
function ttl.consolidateItems()
    -- TODO: Memoize and make more efficient
    for i=16,1,-1 do
        ttl.consolidateSlot(i)
    end
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
    if x2 < x1 then return 2 end
    if z2 > z1 then return 3 end
    error("Bad Rotation Arguments: " .. tostring(x1) .. " " .. tostring(z1) .. " " .. tostring(x2) .. " " .. tostring(z2))
end