local g_elevatorsSyncData = { }
--[[
    {
        lastFloorIndex
        targetFloorIndex
        movementTimestamp

        netOwner
    }
]]

-- Network only elevator states that are on the same grid as the player
AddEventHandler("playerEnteredScope", function(data)
    local for_player = data["for"]
    local player = data.player
end)

--[[
RegisterNetEvent("onMoveElevator")
AddEventHandler("onMoveElevator", function(elevatorId, syncState)
    g_elevatorsSyncData[elevatorId] = syncState

    -- Send to in-scope players only

    TriggerClientEvent("changeElevatorState", -1, elevatorId, g_elevatorsSyncData[elevatorId])
end)
]]

RegisterNetEvent("onElevatorReachTargetFloor")
AddEventHandler("onElevatorReachTargetFloor", function(elevatorId)
    if g_elevatorsSyncData[elevatorId] then
        g_elevatorsSyncData[elevatorId].lastFloorIndex = g_elevatorsSyncData[elevatorId].targetFloorIndex

        -- Wait(100)

        FakeRotativeMovement()
    end
end)

function FakeRotativeMovement()
    local elevatorId = 1

    local lastFloor = 1

    if g_elevatorsSyncData[elevatorId] then
        lastFloor = g_elevatorsSyncData[elevatorId].lastFloorIndex
    end

    local targetFloor = lastFloor + 1

    if targetFloor > #shared_elevators_specs[elevatorId].floors then
        targetFloor = 1
    end

    g_elevatorsSyncData[elevatorId] = {
        movementTimestamp = os.time(),
        lastFloorIndex    = lastFloor,
        targetFloorIndex  = targetFloor,
    }

    TriggerClientEvent("changeElevatorState", -1, elevatorId, g_elevatorsSyncData[elevatorId])
end

CreateThread(function()
    Wait(1000)

    FakeRotativeMovement()
end)