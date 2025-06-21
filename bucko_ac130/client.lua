local QBCore = exports['qb-core']:GetCoreObject()

local isActive = false
local cam = nil
local camRot = vector3(0.0, 0.0, 0.0)
local camCoords = vector3(0.0, 0.0, 0.0)
local missileCount = 15-- NUMBER OF MISSILES .. ADJUST IF YOU WANT TO 

-- Utility notify function
local function Notify(text)
    QBCore.Functions.Notify(text)
end

-- Function to get forward vector from rotation (degrees)
local function GetForwardVector(rot)
    local rotRad = vector3(math.rad(rot.x), math.rad(rot.y), math.rad(rot.z))
    local cx = math.cos(rotRad.z)
    local sx = math.sin(rotRad.z)
    local cy = math.cos(rotRad.x)
    local sy = math.sin(rotRad.x)

    return vector3(-sx * cy, cx * cy, sy)
end

-- Create and activate camera
local function CreateCamera()
    local playerPed = PlayerPedId()
    camCoords = GetEntityCoords(playerPed) + vector3(0, 0, 50)
    camRot = vector3(-90.0, 0.0, GetEntityHeading(playerPed))

    cam = CreateCam("DEFAULT_SCRIPTED_CAMERA", true)
    SetCamCoord(cam, camCoords.x, camCoords.y, camCoords.z)
    SetCamRot(cam, camRot.x, camRot.y, camRot.z, 2)
    SetCamFov(cam, 50.0)
    SetCamActive(cam, true)
    RenderScriptCams(true, false, 0, true, false)
end

local function DestroyCamera()
    if cam then
        RenderScriptCams(false, false, 0, true, false)
        DestroyCam(cam, false)
        cam = nil
    end
end

local function DropBomb()
    if missileCount <= 0 then
        Notify("No bombs left! Exiting AC130 mode.")
        isActive = false
        DestroyCamera()
        
        -- Remove the ac130_controller item from player inventory after all missiles are spent
        TriggerServerEvent('QBCore:RemoveItem', "ac130_controller", 1)
        Notify("AC130 Controller has been used up.")
        
        return
    end

    missileCount = missileCount - 1

    local camCoordsLocal = GetCamCoord(cam)
    local camRotVec = GetCamRot(cam, 2)
    local forwardVector = GetForwardVector(camRotVec)
    local dropDistance = 50.0 -- distance ahead to drop bomb

    local dropX = camCoordsLocal.x + forwardVector.x * dropDistance
    local dropY = camCoordsLocal.y + forwardVector.y * dropDistance
    local dropZ = camCoordsLocal.z + 50.0 -- starting height above cam

    -- Get ground Z at drop point
    local foundGround, groundZ = GetGroundZFor_3dCoord(dropX, dropY, dropZ, false)
    if not foundGround then
        groundZ = dropZ - 20.0 -- fallback
    end

    -- Create instant explosion at ground point
    AddExplosion(dropX, dropY, groundZ, 2, 100.0, true, false, 1.0, true)
    PlaySoundFromCoord(-1, "Explosion", dropX, dropY, groundZ, 0, 0, 0, 0)

    Notify("Bomb dropped! Bombs left: " .. missileCount)
end

-- Main loop for camera control, input & aim marker
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)
        if isActive and cam then
            -- Get input to rotate camera
            local rightAxisX = GetDisabledControlNormal(0, 220) -- Right stick X / mouse X
            local rightAxisY = GetDisabledControlNormal(0, 221) -- Right stick Y / mouse Y

            camRot = vector3(
                math.max(math.min(camRot.x - rightAxisY * 2.0, 0), -90),
                0,
                (camRot.z - rightAxisX * 2.0) % 360
            )

            -- Move camera forward/back/left/right with WASD or arrow keys
            local forward = GetDisabledControlNormal(0, 32) -- W
            local backward = GetDisabledControlNormal(0, 33) -- S
            local left = GetDisabledControlNormal(0, 34) -- A
            local right = GetDisabledControlNormal(0, 35) -- D

            local moveVector = vector3(0, 0, 0)
            local rotRadZ = math.rad(camRot.z)

            -- Calculate directional movement relative to camera rotation
            local forwardVec = vector3(-math.sin(rotRadZ), math.cos(rotRadZ), 0)
            local rightVec = vector3(math.cos(rotRadZ), math.sin(rotRadZ), 0)

            moveVector = moveVector + forwardVec * forward
            moveVector = moveVector - forwardVec * backward
            moveVector = moveVector - rightVec * left
            moveVector = moveVector + rightVec * right

            camCoords = camCoords + moveVector * 0.5

            -- Up/down with Q/E keys
            if IsControlPressed(0, 44) then -- Q
                camCoords = camCoords + vector3(0, 0, -0.5)
            elseif IsControlPressed(0, 38) then -- E
                camCoords = camCoords + vector3(0, 0, 0.5)
            end

            -- Update camera position and rotation
            SetCamCoord(cam, camCoords.x, camCoords.y, camCoords.z)
            SetCamRot(cam, camRot.x, camRot.y, camRot.z, 2)

            -- Calculate aiming point on ground
            local camCoordsLocal = GetCamCoord(cam)
            local camRotVec = GetCamRot(cam, 2)
            local forwardVector = GetForwardVector(camRotVec)
            local aimX = camCoordsLocal.x + forwardVector.x * 50.0
            local aimY = camCoordsLocal.y + forwardVector.y * 50.0
            local aimZ = camCoordsLocal.z + 50.0

            local foundGround, groundZ = GetGroundZFor_3dCoord(aimX, aimY, aimZ, false)
            if not foundGround then groundZ = aimZ - 20.0 end
            local aimCoords = vector3(aimX, aimY, groundZ + 0.5)

            -- Draw a red marker on the ground where you're aiming
            DrawMarker(2, aimCoords.x, aimCoords.y, aimCoords.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 
                1.0, 1.0, 1.0, 255, 0, 0, 150, false, false, 2, false, nil, nil, false)

            -- Fire bomb with SPACE key instantly, no delay
            if IsControlJustPressed(0, 22) then -- SPACEBAR
                DropBomb()
            end
        else
            Citizen.Wait(500)
        end
    end
end)

-- Command to toggle AC130 mode with inventory check
RegisterCommand("ac130", function()
    local player = QBCore.Functions.GetPlayerData()
    local hasItem = false

    for _, item in pairs(player.items) do
        if item.name == "ac130_controller" and item.amount > 0 then
            hasItem = true
            break
        end
    end

    if not hasItem then
        Notify("You need an AC130 Controller to use this command.")
        return
    end

    if not isActive then
        isActive = true
        CreateCamera()
        Notify("AC130 mode activated! Use WASD to move, mouse/right-stick to aim, SPACE to drop bombs.")
    else
        isActive = false
        DestroyCamera()
        Notify("AC130 mode deactivated.")
    end
end)
