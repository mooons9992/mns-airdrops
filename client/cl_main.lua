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
    -- Skip if sound name is empty (used to disable sounds)
    if not soundName or soundName == '' then
        return false
    end

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

-- Proper notification function that respects UI config
local function SendNotification(message, type, duration)
    if Config.UI.notification == 'qb' then
        QBCore.Functions.Notify(message, type, duration)
    elseif Config.UI.notification == 'ox' then
        lib.notify({
            title = 'Airdrop',
            description = message,
            type = type,
            duration = duration
        })
    elseif Config.UI.notification == 'custom' then
        -- Your custom notification code here
    end
end

-- Recurring sound checks (UPDATED: Only plays if sound name is not empty)
CreateThread(function()
    while true do
        Wait(Config.sounds.crate.interval or 5000)
        
        -- If we have an active airdrop and sound is configured, play the beacon sound
        if activeAirdropCoords and Config.sounds.crate.soundName ~= '' then
            PlaySoundIfNearby(
                Config.sounds.crate.soundName, 
                Config.sounds.crate.soundDict, 
                activeAirdropCoords, 
                Config.sounds.crate.maxDistance
            )
        else
            Wait(5000) -- Wait longer if no active airdrop or sound disabled
        end
    end
end)

-- Airdrop start event
RegisterNetEvent('mns-airdrops:client:startAirdrop', function(coords, isAdminTest)
    -- Store coordinates for sound system
    activeAirdropCoords = coords
    
    -- Notify based on distance (only if close enough or is admin test)
    local playerCoords = GetEntityCoords(PlayerPedId())
    local notifyDistance = Config.distances and Config.distances.notificationRange or 1500.0
    
    if isAdminTest or #(playerCoords - coords) < notifyDistance then
        -- Use proper notification with config templates
        local notif = Config.notifications.airdropIncoming
        if isAdminTest then
            notif = Config.notifications.adminTest
        end
        
        -- Send notification
        SendNotification(notif.message, notif.type, notif.duration)
        
        -- Only play sound if close enough
        PlaySoundIfNearby(
            Config.sounds.incoming.soundName, 
            Config.sounds.incoming.soundDict, 
            coords, 
            Config.sounds.incoming.maxDistance
        )
    end
    
    -- Create blips
    airdropBlip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(airdropBlip, Config.blips.airdrop.sprite)
    SetBlipDisplay(airdropBlip, 4)
    SetBlipScale(airdropBlip, Config.blips.airdrop.scale)
    SetBlipAsShortRange(airdropBlip, true)
    SetBlipColour(airdropBlip, Config.blips.airdrop.color)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentSubstringPlayerName(Config.blips.airdrop.name)
    EndTextCommandSetBlipName(airdropBlip)

    radius = AddBlipForRadius(coords, Config.blips.radius.size)
    SetBlipColour(radius, Config.blips.radius.color)
    SetBlipAlpha(radius, Config.blips.radius.alpha)

    -- Create effect
    lib.requestNamedPtfxAsset(Config.flare.asset)
    SetPtfxAssetNextCall(Config.flare.asset)
    effect = StartParticleFxLoopedAtCoord(Config.flare.effect, coords, 0.0, 0.0, 0.0, 1.0, false, false, false, false)
  
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
    SetBlipSprite(planeblip, Config.blips.plane.sprite)
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
            PlaySoundIfNearby(
                Config.sounds.plane.soundName,
                Config.sounds.plane.soundDict,
                activeCoords,
                Config.sounds.plane.maxDistance
            )
            
            -- Drop crate when close enough
            if dist < 300 and not dropped then
                Wait(1000)
                TaskPlaneMission(Pilot, Plane, 0, 0, Config.aircraftDespawnPoint.x, Config.aircraftDespawnPoint.y, Config.aircraftDespawnPoint.z, 6, 0, 0, heading, 3000.0, 500.0)
                spawnCrate(coords)
                dropped = true
            end
            
            -- Delete plane when far enough away
            local deleteDist = Config.distances and Config.distances.planeDeleteDistance or 2000.0
            if dropped and dist > deleteDist then 
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
                -- Use proper notification with config
                local notif = Config.notifications.alreadyLooted
                SendNotification(notif.message, notif.type, notif.duration)
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

-- Success notification for looting
RegisterNetEvent('mns-airdrops:client:lootSuccessful', function()
    local notif = Config.notifications.lootReceived
    SendNotification(notif.message, notif.type, notif.duration)
end)

-- Command to test notifications (for debugging)
RegisterCommand('testairnotify', function()
    SendNotification("This is a test airdrop notification", "primary", 5000)
end, false)

-- Resource stop cleanup
AddEventHandler('onResourceStop', function(resourceName)
    if (GetCurrentResourceName() ~= resourceName) then
        return
    end
    
    -- Clean up all entities and effects
    TriggerEvent('mns-airdrops:client:clearStuff')
end)

-- Update the admin test command
RegisterNetEvent('mns-airdrops:client:adminTestAirdrop', function(coords)
    -- Pass true as second parameter to indicate this is an admin test
    -- This ensures notification shows regardless of distance
    TriggerEvent('mns-airdrops:client:startAirdrop', coords, true)
end)
