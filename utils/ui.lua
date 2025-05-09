local Config = require 'config.config'
local QBCore = exports['qb-core']:GetCoreObject()

local UI = {}

-- Notification function that handles different notification systems
function UI.Notify(player, data)
    local src = type(player) == "number" and player or nil
    
    -- If data is just a string, convert it to the proper format
    local notifyData = type(data) == "string" and {
        title = "Airdrop",  -- Default title for string notifications
        message = data,
        type = "primary",
        duration = 5000
    } or data
    
    -- Handle server-side notifications
    if src then
        if Config.UI.notification == 'qb' then
            TriggerClientEvent('QBCore:Notify', src, notifyData.message, notifyData.type, notifyData.duration)
        elseif Config.UI.notification == 'ox' then
            TriggerClientEvent('ox_lib:notify', src, {
                title = notifyData.title,
                description = notifyData.message,
                type = notifyData.type,
                duration = notifyData.duration
            })
        elseif Config.UI.notification == 'custom' then
            -- Implement your custom notification system here
            TriggerClientEvent('your-custom-notification:show', src, notifyData)
        end
    -- Handle client-side notifications
    else
        if Config.UI.notification == 'qb' then
            QBCore.Functions.Notify(notifyData.message, notifyData.type, notifyData.duration)
        elseif Config.UI.notification == 'ox' then
            lib.notify({
                title = notifyData.title,
                description = notifyData.message,
                type = notifyData.type,
                duration = notifyData.duration
            })
        elseif Config.UI.notification == 'custom' then
            -- Implement your custom client notification here
            -- Example: exports['your-notification-system']:ShowNotification(notifyData)
        end
    end
end

-- Progress bar function that handles different systems
function UI.ProgressBar(data, cb)
    if Config.UI.progressBar == 'qb' then
        QBCore.Functions.Progressbar(data.id or "progress_action", data.label, data.duration, false, data.canCancel or false, {
            disableMovement = data.disable and data.disable.move or true,
            disableCarMovement = data.disable and data.disable.car or true,
            disableMouse = data.disable and data.disable.mouse or false,
            disableCombat = data.disable and data.disable.combat or true,
        }, {
            animDict = data.anim and data.anim.dict or nil,
            anim = data.anim and data.anim.clip or nil,
            flags = data.anim and data.anim.flag or 1,
        }, {}, {}, function() -- Done
            if cb then cb(true) end
        end, function() -- Cancel
            if cb then cb(false) end
        end)
    elseif Config.UI.progressBar == 'ox' then
        lib.progressBar({
            duration = data.duration,
            label = data.label,
            position = data.position or 'bottom',
            useWhileDead = data.useWhileDead or false,
            canCancel = data.canCancel or false,
            disable = {
                car = data.disable and data.disable.car or true,
                move = data.disable and data.disable.move or true,
                combat = data.disable and data.disable.combat or true,
                mouse = data.disable and data.disable.mouse or false,
            },
            anim = data.anim and {
                dict = data.anim.dict,
                clip = data.anim.clip,
                flag = data.anim.flag or 1,
                blendIn = data.anim.blendIn or 1.0,
                blendOut = data.anim.blendOut or 1.0,
            } or nil,
        }, function(cancelled)
            if cb then cb(not cancelled) end
        end)
    end
end

-- Add target to entity with appropriate system
function UI.AddEntityTarget(entity, options)
    if Config.UI.target == 'qb' then
        -- Convert options format for qb-target
        local qbOptions = {
            options = {},
            distance = options[1].distance or 2.5
        }
        
        for _, option in pairs(options) do
            table.insert(qbOptions.options, {
                type = "client",
                icon = option.icon,
                label = option.label,
                action = function()
                    option.onSelect()
                end,
                canInteract = option.canInteract
            })
        end
        
        exports['qb-target']:AddTargetEntity(entity, qbOptions)
    elseif Config.UI.target == 'ox' then
        exports.ox_target:addLocalEntity(entity, options)
    end
end

-- Remove target from entity
function UI.RemoveEntityTarget(entity)
    if Config.UI.target == 'qb' then
        exports['qb-target']:RemoveTargetEntity(entity)
    elseif Config.UI.target == 'ox' then
        exports.ox_target:removeLocalEntity(entity)
    end
end

-- Handle inventory item box notification
function UI.ItemBox(source, item, type)
    local src = source
    
    if Config.UI.inventory == 'qb' then
        TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[item], type)
    elseif Config.UI.inventory == 'ox' then
        -- ox_inventory uses a different notification system
        TriggerClientEvent('ox_inventory:notify', src, {
            title = 'Inventory',
            text = (type == 'add' and 'Received' or 'Removed') .. ' ' .. QBCore.Shared.Items[item].label,
            type = type == 'add' and 'success' or 'error'
        })
    elseif Config.UI.inventory == 'ps' then
        -- ps-inventory compatibility
        TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[item], type)
    end
end

-- Play a sound based on distance - IMPROVED with empty string check
function UI.PlaySoundWithDistance(soundConfig, coords)
    -- Skip if sound name is empty (used to disable sounds)
    if not soundConfig.soundName or soundConfig.soundName == '' then
        return false
    end
    
    -- This function needs to be called client-side
    local playerCoords = GetEntityCoords(PlayerPedId())
    local distance = #(playerCoords - coords)
    
    if distance <= soundConfig.maxDistance then
        -- Calculate volume based on distance (closer = louder)
        local volume = 1.0 - (distance / soundConfig.maxDistance)
        volume = math.max(0.1, volume) -- Ensure volume doesn't go below 0.1
        
        -- Play the sound
        PlaySoundFrontend(-1, soundConfig.soundName, soundConfig.soundRef, false)
        
        -- Return true if sound played
        return true
    end
    
    -- Return false if too far away
    return false
end

-- List of active repeating sounds
local activeSounds = {}

-- Start a repeating sound with distance check - IMPROVED with empty string check
function UI.StartRepeatingSound(id, soundConfig, coords)
    -- Skip if sound name is empty (used to disable sounds)
    if not soundConfig.soundName or soundConfig.soundName == '' then
        return false
    end

    if activeSounds[id] then
        return -- Sound already playing
    end
    
    activeSounds[id] = {
        coords = coords,
        config = soundConfig,
        nextPlay = 0
    }
    
    -- Create thread to manage repeating sound
    if soundConfig.interval and soundConfig.interval > 0 then
        CreateThread(function()
            while activeSounds[id] do
                local now = GetGameTimer()
                if now >= activeSounds[id].nextPlay then
                    local played = UI.PlaySoundWithDistance(soundConfig, coords)
                    if played then
                        activeSounds[id].nextPlay = now + soundConfig.interval
                    end
                end
                Wait(1000) -- Check every second
            end
        end)
    else
        -- Play once
        UI.PlaySoundWithDistance(soundConfig, coords)
    end
    
    return true
end

-- Stop a repeating sound
function UI.StopRepeatingSound(id)
    if activeSounds[id] then
        activeSounds[id] = nil
    end
end

-- Stop all repeating sounds
function UI.StopAllSounds()
    activeSounds = {}
end

-- Send a notification for airdrop using correct config
function UI.AirdropNotify(type, coords, isAdmin)
    if not Config.notifications or not Config.notifications[type] then
        -- Fallback notification if config is missing
        UI.Notify(nil, {
            title = "Airdrop",
            message = "Airdrop " .. type,
            type = "primary",
            duration = 5000
        })
        return
    end

    local notif = Config.notifications[type]
    
    -- Check distance for normal airdrops (not admin tests)
    if not isAdmin and coords then
        local notifyDistance = Config.distances and Config.distances.notificationRange or 1500.0
        local playerCoords = GetEntityCoords(PlayerPedId())
        if #(playerCoords - coords) > notifyDistance then
            return false -- Too far away, don't notify
        end
    end
    
    -- Send notification
    UI.Notify(nil, {
        title = "Airdrop",
        message = notif.message,
        type = notif.type,
        duration = notif.duration
    })
    
    return true
end

-- Create a blip on the map
function UI.CreateBlip(coords, config)
    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    
    if config then
        if config.sprite then SetBlipSprite(blip, config.sprite) end
        if config.scale then SetBlipScale(blip, config.scale) end
        if config.color then SetBlipColour(blip, config.color) end
        if config.name then 
            BeginTextCommandSetBlipName("STRING")
            AddTextComponentSubstringPlayerName(config.name)
            EndTextCommandSetBlipName(blip)
        end
        if config.display then SetBlipDisplay(blip, config.display) end
        if config.shortRange ~= nil then SetBlipAsShortRange(blip, config.shortRange) end
    end
    
    return blip
end

-- Create a radius blip
function UI.CreateRadiusBlip(coords, radius, color, alpha)
    local blip = AddBlipForRadius(coords.x, coords.y, coords.z, radius)
    
    if color then SetBlipColour(blip, color) end
    if alpha then SetBlipAlpha(blip, alpha) end
    
    return blip
end

-- Debug function
function UI.Debug(message)
    if Config.Debug then
        print("^3[MNS-AIRDROPS]^7 " .. message)
    end
end

return UI