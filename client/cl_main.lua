local Config = require 'config.config'
local QBCore = exports['qb-core']:GetCoreObject()

-- Define the crate model at the top of the file for easy changes
local CRATE_MODEL = Config.crateModel or 'gr_prop_gr_crates_guns_01a' -- Use config value or default
local FALLBACK_MODELS = {
    'prop_box_ammo04a',      -- Simple ammo box (loads reliably)
    'prop_mil_crate_01',     -- Basic military crate (loads quickly)
    'ex_prop_crate_ammo_sc', -- Ammo supply crate
    'prop_drop_armscrate_01' -- Default airdrop crate
}

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
local cratePosition = nil

-- Clean up any crates from previous sessions on script start
CreateThread(function()
    -- Wait a moment for everything to initialize
    Wait(2000)
    
    print("[MNS-AIRDROPS] Performing startup cleanup")
    
    -- Clean up any existing crates using hash
    local crateHashes = {
        GetHashKey('gr_prop_gr_crates_guns_01a'),
        GetHashKey('prop_box_ammo04a'),
        GetHashKey('prop_mil_crate_01'),
        GetHashKey('ex_prop_crate_ammo_sc'),
        GetHashKey('prop_drop_armscrate_01')
    }
    
    local objectsToCheck = GetGamePool('CObject')
    local cleanupCount = 0
    
    for _, object in ipairs(objectsToCheck) do
        if DoesEntityExist(object) then
            local objectHash = GetEntityModel(object)
            
            for _, crateHash in ipairs(crateHashes) do
                if objectHash == crateHash then
                    -- This is likely a leftover crate from previous session
                    exports.ox_target:removeLocalEntity(object)
                    DeleteEntity(object)
                    cleanupCount = cleanupCount + 1
                    break
                end
            end
        end
    end
    
    if cleanupCount > 0 then
        print("[MNS-AIRDROPS] Cleaned up " .. cleanupCount .. " leftover crates on script start")
    end
end)

-- Improved model request function with retries and fallbacks
local function RequestModelWithFallback(modelName)
    -- Start with the preferred model
    local modelHash = GetHashKey(modelName)
    RequestModel(modelHash)
    
    -- Wait for model to load (longer timeout - 5 seconds)
    local startTime = GetGameTimer()
    local timeout = 5000 -- 5 seconds
    
    while not HasModelLoaded(modelHash) do
        Wait(50)
        
        -- Check if we've exceeded our timeout
        if GetGameTimer() - startTime > timeout then
            print("[MNS-AIRDROPS] Primary model failed to load: " .. modelName)
            
            -- Try fallback models in sequence
            for _, fallbackModel in ipairs(FALLBACK_MODELS) do
                print("[MNS-AIRDROPS] Attempting fallback model: " .. fallbackModel)
                local fallbackHash = GetHashKey(fallbackModel)
                RequestModel(fallbackHash)
                
                -- Wait for fallback to load (shorter timeout)
                local fallbackStart = GetGameTimer()
                local fallbackTimeout = 2000 -- 2 seconds per fallback attempt
                
                while not HasModelLoaded(fallbackHash) do
                    Wait(50)
                    if GetGameTimer() - fallbackStart > fallbackTimeout then
                        break -- Move to next fallback
                    end
                end
                
                -- If this fallback loaded, use it
                if HasModelLoaded(fallbackHash) then
                    print("[MNS-AIRDROPS] Successfully loaded fallback model: " .. fallbackModel)
                    return fallbackHash, fallbackModel
                end
            end
            
            -- If all fallbacks fail, return 0 to indicate failure
            print("[MNS-AIRDROPS] All models failed to load!")
            return 0, nil
        end
    end
    
    -- Preferred model loaded successfully
    print("[MNS-AIRDROPS] Successfully loaded primary model: " .. modelName)
    return modelHash, modelName
end

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

-- Update the notification function to ensure it works with your framework
local function SendNotification(message, type, duration)
    print("[MNS-AIRDROPS] Sending notification: " .. message) -- Debug message
    
    if Config.UI.notification == 'qb' then
        QBCore.Functions.Notify(message, type, duration)
    elseif Config.UI.notification == 'ox' then
        if lib and lib.notify then
            lib.notify({
                title = 'Airdrop',
                description = message,
                type = type,
                duration = duration
            })
        else
            -- Fallback to QBCore notifications if lib.notify isn't available
            QBCore.Functions.Notify(message, type, duration)
        end
    elseif Config.UI.notification == 'custom' then
        -- Your custom notification code here
        QBCore.Functions.Notify(message, type, duration) -- Fallback
    else
        -- Unknown notification type, use QBCore as fallback
        QBCore.Functions.Notify(message, type, duration)
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

-- Add this function to ensure only one crate exists
function CleanupExistingCrates()
    -- Check if we already have a crate and delete it
    if drop and DoesEntityExist(drop) then
        print("[MNS-AIRDROPS] Cleaning up existing crate before spawning new one")
        exports.ox_target:removeLocalEntity(drop)
        DeleteEntity(drop)
        drop = nil
    end
    
    -- Also check for any objects with the same model nearby
    -- This helps clean up any duplicate crates that somehow got created
    local modelHash = GetHashKey(CRATE_MODEL)
    local playerCoords = GetEntityCoords(PlayerPedId())
    local objectsToCheck = GetGamePool('CObject')
    
    for _, object in ipairs(objectsToCheck) do
        if DoesEntityExist(object) and GetEntityModel(object) == modelHash then
            -- Don't delete our primary crate
            if object ~= drop then
                local objectCoords = GetEntityCoords(object)
                local distance = #(playerCoords - objectCoords)
                
                -- If it's an airdrop crate within a reasonable distance
                if distance < 200.0 then
                    print("[MNS-AIRDROPS] Found and cleaning up duplicate crate")
                    exports.ox_target:removeLocalEntity(object)
                    DeleteEntity(object)
                end
            end
        end
    end
end

-- Function to check for duplicate crates when operating on the main crate
local function CheckForDuplicateCrates()
    local currentCrate = drop
    if not currentCrate or not DoesEntityExist(currentCrate) then return end
    
    -- Get main crate position for comparison
    local mainCratePos = GetEntityCoords(currentCrate)
    local crateHash = GetEntityModel(currentCrate)
    local objectsToCheck = GetGamePool('CObject')
    
    print("[MNS-AIRDROPS] Checking for duplicate crates near main crate")
    
    for _, object in ipairs(objectsToCheck) do
        if DoesEntityExist(object) and object ~= currentCrate and GetEntityModel(object) == crateHash then
            local objectCoords = GetEntityCoords(object)
            local distance = #(mainCratePos - objectCoords)
            
            -- If it's a duplicate crate nearby
            if distance < 20.0 then
                print("[MNS-AIRDROPS] Found duplicate crate very close to main crate - deleting")
                exports.ox_target:removeLocalEntity(object)
                DeleteEntity(object)
            end
        end
    end
end

-- Airdrop start event
RegisterNetEvent('mns-airdrops:client:startAirdrop', function(coords, isAdminTest)
    -- Clean up any existing airdrops first
    TriggerEvent('mns-airdrops:client:clearStuff')
    
    -- Additional cleanup to catch any missed entities
    CleanupExistingCrates()
    
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
    
    -- Aircraft control thread - completely rewired to prevent double drops
    CreateThread(function()
        -- Single boolean to track drop state
        local hasAttemptedDrop = false
        
        while DoesEntityExist(Plane) do
            if not NetworkHasControlOfEntity(Plane) then
                NetworkRequestControlOfEntity(Plane)
                Wait(10)
            end

            SetBlipRotation(planeblip, math.ceil(GetEntityHeading(Plane)))
            if not hasAttemptedDrop then
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
            
            -- SIMPLIFIED DROP LOGIC: Only one path can execute, no race conditions
            if not hasAttemptedDrop and dist < 300 then
                print("[MNS-AIRDROPS] Initiating airdrop procedure")
                hasAttemptedDrop = true  -- Mark that we've attempted a drop to prevent multiple attempts
                
                -- Clean up any existing crate to be absolutely sure
                if drop and DoesEntityExist(drop) then
                    print("[MNS-AIRDROPS] Cleaning up existing crate before attempting to spawn new one")
                    exports.ox_target:removeLocalEntity(drop)
                    DeleteEntity(drop)
                    drop = nil
                end
                
                -- Add slight pause for immersion
                Wait(500)
                
                -- Use our improved model loading function
                local modelHash, modelName = RequestModelWithFallback(CRATE_MODEL)
                
                if modelHash ~= 0 and modelName then
                    print("[MNS-AIRDROPS] Using model: " .. modelName .. " for crate drop")
                    
                    -- ONE method to spawn crate - no multiple paths
                    local dropHeight = math.max(coords.z, coords.z + 50.0)
                    drop = CreateObject(modelHash, coords.x, coords.y, dropHeight, true, true, true)
                    
                    if DoesEntityExist(drop) then
                        print("[MNS-AIRDROPS] Crate created successfully with ID: " .. drop)
                        
                        -- Apply physics settings
                        SetEntityLodDist(drop, 1000)
                        ActivatePhysics(drop)
                        SetObjectPhysicsParams(drop, 200000.0, 1.0, 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0)
                        SetEntityVelocity(drop, 0.0, 0.0, -35.0)
                        
                        -- Add interaction after delay to let it fall
                        CreateThread(function()
                            Wait(5000)
                            if DoesEntityExist(drop) then
                                -- Sanity check to remove duplicates
                                CheckForDuplicateCrates()
                                -- Add interaction
                                AddCrateInteraction(drop)
                            end
                        end)
                    else
                        print("[MNS-AIRDROPS] Critical failure: Could not create crate object")
                    end
                else
                    print("[MNS-AIRDROPS] Fatal error: Could not load any crate model!")
                end
                
                -- ALWAYS redirect the plane after attempting to drop
                TaskPlaneMission(Pilot, Plane, 0, 0, Config.aircraftDespawnPoint.x, 
                                Config.aircraftDespawnPoint.y, Config.aircraftDespawnPoint.z, 
                                6, 0, 0, heading, 3000.0, 500.0)
                
                print("[MNS-AIRDROPS] Airdrop release attempt complete, redirecting aircraft")
            end
            
            -- Delete plane when far enough away
            local deleteDist = Config.distances and Config.distances.planeDeleteDistance or 2000.0
            if hasAttemptedDrop and dist > deleteDist then 
                print("[MNS-AIRDROPS] Aircraft far enough away, cleaning up")
                DeleteEntity(Plane)
                DeleteEntity(Pilot)
                Plane = nil
                Pilot = nil
                planeblip = nil
                break
            end

            Wait(1000)
        end
    end)
end

-- Update the spawnCrate function to accept model parameters
function spawnCrate(coords, modelHash, modelName)
    print("[MNS-AIRDROPS] Spawning crate at coordinates: " .. coords.x .. ", " .. coords.y .. ", " .. coords.z)
    print("[MNS-AIRDROPS] Using model: " .. (modelName or "unknown"))
    
    -- Model should already be loaded, but double-check
    if not HasModelLoaded(modelHash) then
        print("[MNS-AIRDROPS] WARNING: Model not loaded when spawnCrate called")
        RequestModel(modelHash)
        
        -- Quick timeout - model should already be loaded but just in case
        local timeout = 0
        while not HasModelLoaded(modelHash) and timeout < 20 do
            timeout = timeout + 1
            Wait(50)
        end
        
        if not HasModelLoaded(modelHash) then
            print("[MNS-AIRDROPS] ERROR: Still failed to load crate model!")
            return false
        end
    end
    
    -- Get valid ground coordinates with proper Z coordinate
    local ground, groundZ = GetGroundZFor_3dCoord(coords.x, coords.y, coords.z, true)
    if not ground then
        -- If ground check fails, try a few different heights
        print("[MNS-AIRDROPS] Initial ground check failed, trying alternative heights")
        for height = 0, 1000, 200 do
            ground, groundZ = GetGroundZFor_3dCoord(coords.x, coords.y, height, true)
            if ground then 
                print("[MNS-AIRDROPS] Found ground at height " .. groundZ)
                break 
            end
        end
        
        -- Final fallback if still no ground found
        if not ground then
            print("[MNS-AIRDROPS] WARNING: Could not find ground, using sea level")
            groundZ = 0 -- Default to sea level if ground cannot be found
        end
    end
    
    -- Create the crate at a safe height above the ground
    local spawnHeight = math.max(groundZ + 100, coords.z)
    print("[MNS-AIRDROPS] Creating crate at height " .. spawnHeight)
    
    -- Spawn the crate
    drop = CreateObject(modelHash, coords.x, coords.y, spawnHeight, true, true)
    
    -- Verify crate was spawned successfully
    if not DoesEntityExist(drop) then
        print("[MNS-AIRDROPS] ERROR: Failed to create crate object")
        return false
    else
        print("[MNS-AIRDROPS] Crate created successfully with ID: " .. drop)
    end
    
    -- Set better physics parameters for reliable falling
    SetEntityLodDist(drop, 1000)
    ActivatePhysics(drop)
    
    -- Adjust physics based on the model
    SetObjectPhysicsParams(drop, 200000.0, 1.0, 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0)
    SetEntityVelocity(drop, 0.0, 0.0, -35.0)
    
    -- Add parachute if enabled
    if Config.enableParachuteEffect then
        -- Use a simple parachute model that loads quickly
        local parachuteHash = GetHashKey("p_parachute1_sp_dec")
        RequestModel(parachuteHash)
        
        local parachuteLoaded = false
        for i = 1, 20 do -- Try for 1 second max
            Wait(50)
            if HasModelLoaded(parachuteHash) then
                parachuteLoaded = true
                break
            end
        end
        
        if parachuteLoaded then
            local parachute = CreateObject(parachuteHash, coords.x, coords.y, spawnHeight + 3.0, true, true)
            if DoesEntityExist(parachute) then
                AttachEntityToEntity(parachute, drop, 0, 0.0, 0.0, 2.0, 0.0, 0.0, 0.0, true, true, true, false, 2, true)
                
                -- Delete parachute after landing
                CreateThread(function()
                    while DoesEntityExist(parachute) and DoesEntityExist(drop) do
                        Wait(1000)
                        local cratePos = GetEntityCoords(drop)
                        local ground, groundZ = GetGroundZFor_3dCoord(cratePos.x, cratePos.y, cratePos.z, true)
                        
                        if ground and math.abs(cratePos.z - groundZ) < 1.5 then
                            -- Crate has landed, detach and delete parachute after delay
                            Wait(2000)
                            DetachEntity(parachute, true, true)
                            DeleteEntity(parachute)
                            break
                        end
                    end
                end)
            end
        else
            print("[MNS-AIRDROPS] Could not load parachute model")
        end
    end
    
    -- Add stuck prevention code as before...
    
    -- Add interaction when ready
    CreateThread(function()
        -- Wait a bit to ensure physics are settled
        Wait(3000)
        if DoesEntityExist(drop) then
            -- Check for duplicates that might have spawned
            CheckForDuplicateCrates()
            -- Then add the interaction
            AddCrateInteraction(drop)
        end
    end)
    
    return true
end

-- Add a debug message after the sync event
local function StartLooting(crateObj)
    -- Update position again when interaction begins to ensure accuracy
    local currentCratePos = GetEntityCoords(crateObj)
    TriggerServerEvent("mns-airdrops:server:updateCratePosition", currentCratePos)
    
    -- Debug to console
    print("[MNS-AIRDROPS] Starting loot process...")
    
    -- Sync loot state
    TriggerServerEvent("mns-airdrops:server:sync:loot")
    
    -- Show progress bar
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
    }) then
        -- Debug message before triggering server event
        print("[MNS-AIRDROPS] Progress complete, getting loot from server...")
        TriggerServerEvent('mns-airdrops:server:getLoot')
    end
end

-- Update the AddCrateInteraction function
function AddCrateInteraction(crateObj)
    if not DoesEntityExist(crateObj) then return end
    
    -- Get and store the actual crate position for accurate distance checking
    cratePosition = GetEntityCoords(crateObj)
    -- Send this to the server to update the position for distance checks
    TriggerServerEvent("mns-airdrops:server:updateCratePosition", cratePosition)
    
    exports.ox_target:addLocalEntity(crateObj, {{
        name = 'airdrop_box',
        icon = 'fa-solid fa-parachute-box',
        label = "Loot Supplies",
        distance = 1.5,
        onSelect = function()
            -- First check if player already looted this crate
            local hasLooted = lib.callback.await('mns-airdrops:server:getLootState', false)
            if hasLooted then
                local notif = Config.notifications.alreadyLooted
                SendNotification(notif.message, notif.type, notif.duration)
                return
            end
            
            -- Update position again when interaction begins to ensure accuracy
            local currentCratePos = GetEntityCoords(crateObj)
            TriggerServerEvent("mns-airdrops:server:updateCratePosition", currentCratePos)
            
            -- Check inventory space BEFORE starting the progress bar
            local hasEnoughSpace = CheckInventorySpace()
            
            if not hasEnoughSpace then
                -- Notify player of insufficient space
                SendNotification(Config.notifications.inventoryFull.message, 
                                Config.notifications.inventoryFull.type, 
                                Config.notifications.inventoryFull.duration)
                return
            end
            
            -- Only if we have space, start the looting process
            TriggerServerEvent("mns-airdrops:server:sync:loot")
            
            -- Now show progress bar
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
            }) then
                TriggerServerEvent('mns-airdrops:server:getLoot')
            end
        end
    }})
end

-- Add a function to check inventory space before starting progress bar
function CheckInventorySpace()
    local hasSpace = true
    local inventoryType = Config.UI.inventory:lower()
    
    if inventoryType == 'ox' then
        -- ox_inventory uses different exports
        if exports.ox_inventory then
            -- Get inventory free space if using ox_inventory
            local playerInventory = exports.ox_inventory:GetInventoryItems()
            local emptySlots = 0
            
            -- Count empty slots in inventory
            if playerInventory then
                local maxSlots = exports.ox_inventory:GetSlotCount('player') or 50
                local usedSlots = 0
                
                for _, item in pairs(playerInventory) do
                    if item.slot then
                        usedSlots = usedSlots + 1
                    end
                end
                
                emptySlots = maxSlots - usedSlots
            end
            
            -- Need minimum slots based on config
            local minSlots = type(Config.amountOfItems) == "table" 
                           and Config.amountOfItems[2] or 3  -- Use upper bound if it's a range
                           or Config.amountOfItems or 3     -- Or use fixed amount
                           
            if emptySlots < minSlots then
                hasSpace = false
            end
        end
    elseif inventoryType == 'qb' or inventoryType == 'ps' then
        -- QBCore or PS inventory space check
        local QBCore = exports['qb-core']:GetCoreObject()
        local Player = QBCore.Functions.GetPlayerData()
        local freeSlots = 0
        
        if Player and Player.items then
            local totalSlots = 41  -- Default QBCore slots
            local usedSlots = 0
            
            for _, item in pairs(Player.items) do
                if item and item.slot then
                    usedSlots = usedSlots + 1
                end
            end
            
            freeSlots = totalSlots - usedSlots
        end
        
        -- Need minimum slots based on config
        local minSlots = type(Config.amountOfItems) == "table" 
                       and Config.amountOfItems[2] or 3  -- Use upper bound if it's a range
                       or Config.amountOfItems or 3     -- Or use fixed amount
        
        if freeSlots < minSlots then
            hasSpace = false
        end
    end
    
    return hasSpace
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

-- Add this at the bottom of your script file
CreateThread(function()
    -- Preload all possible models at script start
    print("[MNS-AIRDROPS] Preloading crate models")
    
    -- Try to load the primary model
    RequestModel(GetHashKey(CRATE_MODEL))
    
    -- Also try to load all fallback models
    for _, model in ipairs(FALLBACK_MODELS) do
        RequestModel(GetHashKey(model))
    end
    
    -- Release them after loading to free memory
    Wait(5000)
    SetModelAsNoLongerNeeded(GetHashKey(CRATE_MODEL))
    for _, model in ipairs(FALLBACK_MODELS) do
        SetModelAsNoLongerNeeded(GetHashKey(model))
    end
    
    print("[MNS-AIRDROPS] Finished preloading models")
end)

-- Event for inventory full notification 
RegisterNetEvent('mns-airdrops:client:notifyInventoryFull', function()
    -- Use the config notification system
    SendNotification(
        "You don't have enough inventory space for the loot", 
        "error", 
        5000
    )
end)

-- Event for failed item add notification
RegisterNetEvent('mns-airdrops:client:notifyItemAddFailed', function()
    -- Use the config notification system
    SendNotification(
        "Couldn't add all items to your inventory", 
        "error", 
        5000
    )
end)

-- Add this event handler for consistent notifications
RegisterNetEvent('mns-airdrops:client:notification', function(message, type, duration)
    SendNotification(message, type, duration)
end)
