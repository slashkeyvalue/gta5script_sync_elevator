local RENDER_DISTANCE      = 50.0
local ELEVATOR_SPEED       = 0.01
local ELEVATOR_TRAVEL_TIME = (ELEVATOR_SPEED * 100) * 136.6

local g_elevatorsSyncData = { }

local g_elevatorsEntity = { }

local g_elevatorsMarkedToStopTicking = { }

CreateThread(function()
    -- SetEntityCoords(PlayerPedId(), shared_elevators_specs[1].floors[1])

    while true do
        local playerPed = PlayerPedId()
        local playerPos = GetEntityCoords(playerPed)

        for elevatorId, elevator_specs in ipairs(shared_elevators_specs) do
            local firstFloorPos = elevator_specs.floors[1]

            local dist = #(playerPos - firstFloorPos)

            if not g_elevatorsEntity[elevatorId] then
                if dist <= RENDER_DISTANCE then
                    MakeElevatorEntity(elevatorId)
                end
            else
                if dist > RENDER_DISTANCE then
                    DeleteElevatorEntity(elevatorId)
                end
            end
        end

        Wait(1000)
    end
end)

function MakeElevatorEntity(elevatorId)
    local modelHashed = `xm_prop_iaa_base_elevator`
    -- modelHashed = `xm_base_cia_chair_conf`

    if not IsModelValid(modelHashed) then
        print("This model is not valid, the fuck you doing?")
        return false
    end

    if not HasModelLoaded(modelHashed) then
        RequestModel(modelHashed)

        while not HasModelLoaded(modelHashed) do
            Wait(0)
        end
    end

    local correctFloorPos = CalcCorrectPositionFromLastSyncTimestamp(elevatorId)

    local entity = CreateObject(modelHashed, correctFloorPos, false, false, false)

    g_elevatorsEntity[elevatorId] = entity
    return true
end

function DeleteElevatorEntity(elevatorId)
    if g_elevatorsEntity[elevatorId] then
        DeleteEntity(elevatorId)

        g_elevatorsEntity[elevatorId] = nil
    end
end

function TickElevatorState(elevatorId)
    local state = g_elevatorsSyncData[elevatorId]

    if not state then
        return
    end

    local entity = g_elevatorsEntity[elevatorId]

    local dimensionMin, dimensionMax = GetModelDimensions(GetEntityModel(entity))

    local modelLowerCenterPos = GetOffsetFromEntityInWorldCoords(entity, 0.0, 0.0, dimensionMin.z)

    local correctPos = CalcCorrectPositionFromLastSyncTimestamp(elevatorId)

    -- Prevent entity flickering.
    if #(modelLowerCenterPos - correctPos) > 0.14 then
        SetEntityCoords(entity, correctPos)
    end

    local targetFloorPos = shared_elevators_specs[elevatorId].floors[state.targetFloorIndex]

    local slidePos = vec3(0.0, 0.0, 1.0)

    if IsPositionHigherThan(GetEntityCoords(entity), targetFloorPos) then
        slidePos = vec3(0.0, 0.0, -1.0)
    end

    CreateThread(function()
        while true do 
            Wait(0)

            if g_elevatorsMarkedToStopTicking[elevatorId] then
                g_elevatorsMarkedToStopTicking[elevatorId] = nil

                TriggerServerEvent("onElevatorReachTargetFloor", elevatorId)
                return
            end

            modelLowerCenterPos = GetOffsetFromEntityInWorldCoords(entity, 0.0, 0.0, dimensionMin.z)

            SlideObject(entity, modelLowerCenterPos + slidePos, 0.0, 0.0, ELEVATOR_SPEED, true)

            if #(modelLowerCenterPos - targetFloorPos) <= 0.07 then
                g_elevatorsMarkedToStopTicking[elevatorId] = true
            end

            DrawLine(modelLowerCenterPos, modelLowerCenterPos + vec3(5.0, 0.0, 0.0), 0, 255, 0, 255)
            DrawLine(targetFloorPos, targetFloorPos + vec3(0.0, 0.0, 1.0), 255, 0, 0, 255)
            -- Draw(entity)
        end
    end)
end

--[[
function MoveElevator(elevatorId, targetFloorIndex)
    if not g_elevatorsSyncData[elevatorId] then
        -- The server should re-send me the state then?
    else
        g_elevatorsSyncData[elevatorId].targetFloorIndex = targetFloorIndex

        g_elevatorsSyncData[elevatorId].movementTimestamp = GetGameTimer()
    end

    TriggerServerEvent("onMoveElevator", elevatorId, g_elevatorsSyncData[elevatorId])

    TickElevatorState(elevatorId)
end
]]

RegisterNetEvent("changeElevatorState")
AddEventHandler("changeElevatorState", function(elevatorId, state)
    -- print("changeElevatorState", elevatorId, json.encode(state))

    g_elevatorsSyncData[elevatorId] = state

    TickElevatorState(elevatorId)
end)

function CalcCorrectPositionFromLastSyncTimestamp(elevatorId)
    local floorsPos = shared_elevators_specs[elevatorId].floors

    local firstFloorPos = floorsPos[1]
    local correctFlorPos = firstFloorPos

    local state = g_elevatorsSyncData[elevatorId]

    if state then
        correctFlorPos = floorsPos[state.lastFloorIndex]
        
        if state.targetFloorIndex then
            local fromFloorPos = correctFlorPos
            local toFloorPos = floorsPos[state.targetFloorIndex]

            local heightDiff = toFloorPos.z - fromFloorPos.z

            local isHeightDiffNeg = heightDiff < 0

            -- #TODO: GetCloudTimeAsInt probably doesn't return server time precisely.
            local alreadyTravelledTime = GetCloudTimeAsInt() - state.movementTimestamp

            local heightAddition = alreadyTravelledTime / ELEVATOR_TRAVEL_TIME

            heightAddition = math.min(math.abs(heightAddition), math.abs(heightDiff))

            if isHeightDiffNeg then
                heightAddition = -heightAddition
            end

            correctFlorPos = fromFloorPos + vec3(0.0, 0.0, heightAddition)
        end
    end

    return correctFlorPos
end

function IsPositionHigherThan(pos_a, pos_b)
    return pos_a.z > pos_b.z
end

local rgb = quat(10, 0, 255, 0)

function Draw(entity)
    -- // _SET_VEHICLE_FORWARD_VECTOR_SPEED
    -- N_0x6501129c9e0ffa05(entity, 10.0)

    -- // 0x4D107406667423BE
    -- _UIPROMPT_CONTEXT_SET_ENTITY_OR_VOLUME/_UIPROMPT_ATTACH_TO

    -- // 0xD6BD313CFA41E57A
    -- _UIPROMPT_IS_CONTROL_PRESSED

    local dimensionMin, dimensionMax = GetModelDimensions(GetEntityModel(entity))

    local offsetA = GetOffsetFromEntityInWorldCoords(entity, dimensionMax)
    local offsetB = GetOffsetFromEntityInWorldCoords(entity, dimensionMin.x, dimensionMax.y, dimensionMax.z)
    local offsetC = GetOffsetFromEntityInWorldCoords(entity, dimensionMax.x, dimensionMin.y, dimensionMax.z)
    local offsetD = GetOffsetFromEntityInWorldCoords(entity, dimensionMin.x, dimensionMin.y, dimensionMax.z)
    local offsetE = GetOffsetFromEntityInWorldCoords(entity, dimensionMax.x, dimensionMax.y, dimensionMin.z)
    local offsetF = GetOffsetFromEntityInWorldCoords(entity, dimensionMin.x, dimensionMax.y, dimensionMin.z)
    local offsetG = GetOffsetFromEntityInWorldCoords(entity, dimensionMax.x, dimensionMin.y, dimensionMin.z)
    local offsetH = GetOffsetFromEntityInWorldCoords(entity, dimensionMin)

    DrawLine(offsetA, offsetB, rgb.x, rgb.y, rgb.z, 150)
    DrawLine(offsetB, offsetD, rgb.x, rgb.y, rgb.z, 150)
    DrawLine(offsetD, offsetC, rgb.x, rgb.y, rgb.z, 150)
    DrawLine(offsetC, offsetA, rgb.x, rgb.y, rgb.z, 150)
    DrawLine(offsetE, offsetF, rgb.x, rgb.y, rgb.z, 150)
    DrawLine(offsetF, offsetH, rgb.x, rgb.y, rgb.z, 150)
    DrawLine(offsetH, offsetG, rgb.x, rgb.y, rgb.z, 150)
    DrawLine(offsetG, offsetE, rgb.x, rgb.y, rgb.z, 150)
    DrawLine(offsetA, offsetE, rgb.x, rgb.y, rgb.z, 150)
    DrawLine(offsetB, offsetF, rgb.x, rgb.y, rgb.z, 150)
    DrawLine(offsetD, offsetH, rgb.x, rgb.y, rgb.z, 150)
    DrawLine(offsetC, offsetG, rgb.x, rgb.y, rgb.z, 150)

    -- DrawPoly(offsetA, offsetB, offsetD, rgb.x, rgb.y, rgb.z, rgb.w)
    -- DrawPoly(offsetD, offsetC, offsetA, rgb.x, rgb.y, rgb.z, rgb.w)
    -- DrawPoly(offsetB, offsetA, offsetE, rgb.x, rgb.y, rgb.z, rgb.w)
    -- DrawPoly(offsetE, offsetF, offsetB, rgb.x, rgb.y, rgb.z, rgb.w)
    -- DrawPoly(offsetC, offsetD, offsetH, rgb.x, rgb.y, rgb.z, rgb.w)
    -- DrawPoly(offsetH, offsetG, offsetC, rgb.x, rgb.y, rgb.z, rgb.w)
    -- DrawPoly(offsetG, offsetH, offsetF, rgb.x, rgb.y, rgb.z, rgb.w)
    -- DrawPoly(offsetF, offsetE, offsetG, rgb.x, rgb.y, rgb.z, rgb.w)
    -- DrawPoly(offsetD, offsetB, offsetF, rgb.x, rgb.y, rgb.z, rgb.w)
    -- DrawPoly(offsetF, offsetH, offsetD, rgb.x, rgb.y, rgb.z, rgb.w)
    -- DrawPoly(offsetA, offsetC, offsetG, rgb.x, rgb.y, rgb.z, rgb.w)
    -- DrawPoly(offsetG, offsetE, offsetA, rgb.x, rgb.y, rgb.z, rgb.w)
end

AddEventHandler("onResourceStop", function(resource)
    if resource == "_slash__elevator" then
        for _, entity in ipairs(g_elevatorsEntity) do
            SetEntityAsMissionEntity(entity, true, true)
            DeleteEntity(entity)
        end
    end
end)