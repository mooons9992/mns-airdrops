local Config = require 'config.config'
local QBCore = exports['qb-core']:GetCoreObject()

-- Local variables for tracking entities and effects
local airdropBlip = nil
local radius = nil
local Plane = nil
local Pilot = nil
local planeblip = nil
local effect = nil
local drop = nil
local activeAirdropCoords = nil
local soundPlaying = false

-- Function to play sound based on distance
local function PlaySoundIfNearby(soundName, soundDict, coords, maxDistance)
    local playerCoords = GetEntityCoords(PlayerPedId())
    local distance = #(playerCoords - coords)
    
    if distance <= maxDistance then
        -- Calculate volume based on distance (closer = louder)
        local volume = 1.0 - (distance / maxDistance)
        volume = math.max(0.1, volume) -- Ensure volume doesn't go below 0.1
        
        -- Play the sound with appropriate volume
        PlaySoundFrontend(-1, soundName, soundDict, false)
        return true
    end
    
    return false
end

-- Recurring sound checks
CreateThread(function()
    while true do
        Wait(5000) -- Check every 5 seconds
        
        -- If we have an active airdrop, check if we should play the beacon sound
        if activeAirdropCoords then
            PlaySoundIfNearby('Crate_Beeps', 'MP_CRATE_DROP_SOUNDS', activeAirdropCoords, 150.0)
        else
            Wait(5000) -- Wait longer if no active airdrop
        end
    end
end)

-- Airdrop start event
RegisterNetEvent('mns-airdrops:client:startAirdrop', function(coords)
    -- Store coordinates for sound system
    activeAirdropCoords = coords
    
    -- Notify based on distance (only if close enough)
    local playerCoords = GetEntityCoords(PlayerPedId())
    if #(playerCoords - coords) < 1500.0 then
        QBCore.Functions.Notify("Airdrop incoming!", "primary", 5000)
        
        -- Only play sound if close enough
        PlaySoundIfNearby('Mission_Pass_Notify', 'DLC_HEISTS_GENERAL_FRONTEND_SOUNDS', coords, 1000.0)
    end
    
    -- Create blips
    airdropBlip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(airdropBlip, 550)
    SetBlipDisplay(airdropBlip, 4)
    SetBlipScale(airdropBlip, 0.7)
    SetBlipAsShortRange(airdropBlip, true)
    SetBlipColour(airdropBlip, 1)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentSubstringPlayerName("Air Drop")
    EndTextCommandSetBlipName(airdropBlip)

    radius = AddBlipForRadius(coords, 120.0)
    SetBlipColour(radius, 1)
    SetBlipAlpha(radius, 80)

    -- Create effect
    lib.requestNamedPtfxAsset("scr_biolab_heist")
    SetPtfxAssetNextCall("scr_biolab_heist")
    effect = StartParticleFxLoopedAtCoord("scr_heist_biolab_flare", coords, 0.0, 0.0, 0.0, 1.0, false, false, false, false)
  
    -- Spawn aircraft
    spawnAirPlane(coords)
end)

-- Aircraft spawning function
function spawnAirPlane(coords)
    local dropped = false
    local heading = GetHeadingFromVector_2d(coords.x - Config.aircraftSpawnPoint.x, coords.y - Config.aircraftSpawnPoint.y)

    lib.requestModel(Config.AirCraft.PlaneModel)
    lib.requestModel(Config.AirCraft.PilotModel)

    Plane = CreateVehicle(GetHashKey(Config.AirCraft.PlaneModel), Config.aircraftSpawnPoint.x, Config.aircraftSpawnPoint.y, Config.aircraftSpawnPoint.z, heading, false, true)
    Pilot = CreatePed(4, GetHashKey(Config.AirCraft.PilotModel), Config.aircraftSpawnPoint.x, Config.aircraftSpawnPoint.y, Config.aircraftSpawnPoint.z, heading, false, true)

    lib.waitFor(function()
        if DoesEntityExist(Plane) and DoesEntityExist(Pilot) then
            return true
        end
    end, "entity does not exist")

    planeblip = AddBlipForEntity(Plane)
    SetBlipSprite(planeblip, 307)
    SetBlipRotation(planeblip, GetEntityHeading(Pilot))
    SetPedIntoVehicle(Pilot, Plane, -1)

    ControlLandingGear(Plane, 3)
    SetVehicleEngineOn(Plane, true, true, false)
    SetEntityVelocity(Plane, 0.9 * Config.AirCraft.Speed, 0.9 * Config.AirCraft.Speed, 0.0)
    
    -- Make entities invincible for stability
    SetEntityInvincible(Plane, true)
    SetEntityInvincible(Pilot, true)
    
    -- Aircraft control thread
    CreateThread(function()
        while DoesEntityExist(Plane) do
            if not NetworkHasControlOfEntity(Plane) then
                NetworkRequestControlOfEntity(Plane)
                Wait(10)
            end

            SetBlipRotation(planeblip, math.ceil(GetEntityHeading(Plane)))
            if not dropped then
                TaskPlaneMission(Pilot, Plane, 0, 0, coords.x, coords.y, coords.z + 250, 6, 0, 0, heading, 3000.0, 500.0)
            end
            
            local activeCoords = GetEntityCoords(Plane)
            local dist = #(activeCoords - coords)
            
            -- Play plane sound based on distance
            PlaySoundIfNearby('Flying_By', 'MP_MISSION_COUNTDOWN_SOUNDSET', activeCoords, 600.0)
            
            -- Drop crate when close enough
            if dist < 300 and not dropped then
                Wait(1000)
                TaskPlaneMission(Pilot, Plane, 0, 0, -2194.32, 5120.9, Config.AirCraft.Height, 6, 0, 0, heading, 3000.0, 500.0)
                spawnCrate(coords)
                dropped = true
            end
            
            -- Delete plane when far enough away
            if dropped and dist > 2000 then 
                DeleteEntity(Plane)
                DeleteEntity(Pilot)
                Plane = nil
                Pilot = nil
                planeblip = nil
                dropped = false
                break
            end

            Wait(1000)
        end
    end)
end

-- Crate spawning function
function spawnCrate(coords)
    Wait(1000)
    lib.requestModel('prop_drop_armscrate_01')
    drop = CreateObject('prop_drop_armscrate_01', coords.x, coords.y, coords.z + 200, false, true)

    lib.waitFor(function()
        if DoesEntityExist(drop) then
            return true
        end
    end, "entity does not exist")
    
    SetObjectPhysicsParams(drop, 80000.0, 0.1, 0.0, 0.0, 0.0, 700.0, 0.0, 0.0, 0.0, 0.1, 0.0)
    SetEntityLodDist(drop, 1000)
    ActivatePhysics(drop)
    SetDamping(drop, 2, Config.falldownSpeed)
    SetEntityVelocity(drop, 0.0, 0.0, -7000.0)

    exports.ox_target:addLocalEntity(drop, {{
        name = 'airdrop_box',
        icon = 'fa-solid fa-parachute-box',
        label = "Loot Supplies",
        distance = 1.5,
        onSelect = function()
            local state = lib.callback.await('mns-airdrops:server:getLootState', false)
            if not state then
                TriggerServerEvent("mns-airdrops:server:sync:loot")
                if lib.progressBar({
                    label = "Looting",
                    duration = Config.progressbarDuration,
                    position = 'bottom',
                    canCancel = false,
                    disable = {
                        move = true,
                        combat = true,
                    },
                    anim = {
                        dict = 'missexile3',
                        clip = 'ex03_dingy_search_case_base_michael',
                        flag = 1,
                        blendIn = 1.0
                    },
                }) 
                then
                    TriggerServerEvent('mns-airdrops:server:getLoot')
                end
            else
                QBCore.Functions.Notify("This was already looted or being looted", "error")
            end
        end
    }})
end

-- Cleanup event
RegisterNetEvent('mns-airdrops:client:clearStuff', function()
    -- Reset airdrop coordinates
    activeAirdropCoords = nil
    
    -- Stop effects and delete entities
    if effect then StopParticleFxLooped(effect, 0) end
    if drop then 
        exports.ox_target:removeLocalEntity(drop)
        DeleteEntity(drop) 
    end
    if Pilot then DeleteEntity(Pilot) end
    if Plane then DeleteEntity(Plane) end
    
    -- Remove blips
    if airdropBlip then RemoveBlip(airdropBlip) end
    if radius then RemoveBlip(radius) end
    if planeblip then RemoveBlip(planeblip) end
    
    -- Reset variables
    effect = nil
    drop = nil
    Pilot = nil
    Plane = nil
    airdropBlip = nil
    radius = nil
    planeblip = nil
end)

-- Resource stop cleanup
AddEventHandler('onResourceStop', function(resourceName)
    if (GetCurrentResourceName() ~= resourceName) then
        return
    end
    
    -- Clean up all entities and effects
    TriggerEvent('mns-airdrops:client:clearStuff')
end)
