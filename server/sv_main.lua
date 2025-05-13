local Config = require 'config.config'
local QBCore = exports['qb-core']:GetCoreObject()

local waitTime = Config.intervalBetweenAirdrops * 60000
local loc = nil
local looted = false
local cratePosition = nil
local lootedPlayers = {}  -- Track which players have looted
local deleteTimerActive = false -- Track if delete timer is active

-- Add this event to update the crate position
RegisterNetEvent("mns-airdrops:server:updateCratePosition", function(position)
    local src = source
    if position then
        cratePosition = position
        -- Optional debug print
        print("^2[MNS-AIRDROPS]^7 Updated crate position from player " .. src)
    end
end)

-- Regular airdrops on the configured interval
CreateThread(function()
  while true do
      Wait(waitTime)
      
      -- Reset looted status and crate position
      looted = false
      lootedPlayers = {}  -- Reset the player tracking
      deleteTimerActive = false -- Reset timer tracking
      
      -- Notify clients to clean up
      TriggerClientEvent("mns-airdrops:client:clearStuff", -1)
      
      local randomloc = math.random(1, #Config.Locs)
      loc = Config.Locs[randomloc]  
      cratePosition = loc
      -- Pass false to indicate this is not an admin test
      TriggerClientEvent("mns-airdrops:client:startAirdrop", -1, loc, false)
      
      -- Log to console
      print("^2[MNS-AIRDROPS]^7 Airdrop started at location: " .. loc.x .. ", " .. loc.y .. ", " .. loc.z)
  end
end)

-- Sync looting state between players - Improved version
RegisterNetEvent("mns-airdrops:server:sync:loot", function()
  local src = source
  print("^3[MNS-AIRDROPS]^7 Player ID " .. src .. " syncing loot state")
  
  -- Mark as ready to loot immediately - we'll check inventory space in the actual loot function
  looted = true
  print("^2[MNS-AIRDROPS]^7 Airdrop marked as ready to loot")
end)

-- Modify the server-side getLoot function to not delete the crate when inventory is full
RegisterNetEvent("mns-airdrops:server:getLoot", function()
  local src = source
  print("^3[MNS-AIRDROPS]^7 Player ID " .. src .. " is attempting to loot")
  
  -- Check if already looted by this player
  if not looted then 
    print("^3[MNS-AIRDROPS]^7 Loot request denied - airdrop is not marked as ready to loot")
    TriggerClientEvent('mns-airdrops:client:notification', src, 
                      "This airdrop is not ready to be looted", "error", 3000)
    return 
  end
  
  -- Track who has looted - initialize if needed
  if not lootedPlayers then
    lootedPlayers = {}
  end
  
  -- Check if this player already looted
  if lootedPlayers[src] then
    TriggerClientEvent('mns-airdrops:client:notification', src, 
                    "You've already looted this airdrop", "error", 3000)
    print("^3[MNS-AIRDROPS]^7 Player ID " .. src .. " already looted this airdrop")
    return
  end
  
  -- Send current player position with the loot request
  local playerCoords = GetEntityCoords(GetPlayerPed(src))
  
  -- Check distance to crate
  local maxDistance = Config.distances and Config.distances.lootingDistance or 10.0
  
  if cratePosition and #(playerCoords - cratePosition) > maxDistance then
    print("^3[MNS-AIRDROPS]^7 Player ID " .. src .. " attempted to loot from distance: " .. 
      #(playerCoords - cratePosition) .. " meters (max allowed: " .. maxDistance .. ")")
    -- Deny the loot
    TriggerClientEvent('mns-airdrops:client:notification', src, "You're too far away", "error", 3000)
    return
  end
  
  local Player = QBCore.Functions.GetPlayer(src)
  if not Player then 
    print("^1[MNS-AIRDROPS]^7 ERROR: Could not get player data for ID " .. src)
    return 
  end
  
  -- Determine number of items to give
  local amountOfItems = Config.amountOfItems
  if type(amountOfItems) == "table" then
    amountOfItems = math.random(amountOfItems[1], amountOfItems[2])
  end
  
  -- Check inventory space BEFORE giving items
  local hasEnoughSpace = true
  local freeSlots = 0
  
  -- Try to get slot count (compatible with different inventory systems)
  if Config.UI.inventory:lower() == 'ox' then
    if exports.ox_inventory then
      -- Using ox_inventory
      local canCarry = exports.ox_inventory:CanCarryItems(src, amountOfItems)
      if not canCarry then
        hasEnoughSpace = false
      end
    end
  else
    -- QBCore inventory check
    local maxSlots = 41 -- Default QBCore slots
    local usedSlots = 0
    
    for _, item in pairs(Player.PlayerData.items) do
      if item and item.slot then
        usedSlots = usedSlots + 1
      end
    end
    
    freeSlots = maxSlots - usedSlots
    if freeSlots < amountOfItems then
      hasEnoughSpace = false
    end
  end
  
  -- If not enough space, notify and DON'T mark as looted for this player
  if not hasEnoughSpace then
    TriggerClientEvent('mns-airdrops:client:notification', src, 
                    Config.notifications.inventoryFull.message, 
                    Config.notifications.inventoryFull.type, 
                    Config.notifications.inventoryFull.duration)
    print("^3[MNS-AIRDROPS]^7 Player ID " .. src .. " has insufficient inventory space")
    return -- Return WITHOUT marking the player as having looted
  end
  
  print("^3[MNS-AIRDROPS]^7 Player ID " .. src .. " successfully looting - giving " .. amountOfItems .. " items")
  
  -- Mark this player as having looted ONLY if they have enough space
  lootedPlayers[src] = true
  
  -- Give items
  local successfullyAdded = 0
  local givenItems = {}
  
  for i = 1, amountOfItems do
    local randItem = Config.LootTable[math.random(1, #Config.LootTable)]
    print("^3[MNS-AIRDROPS]^7 Attempting to give item: " .. randItem)
    
    local success = Player.Functions.AddItem(randItem, 1)
    
    if success then
      table.insert(givenItems, QBCore.Shared.Items[randItem].label or randItem)
      TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[randItem], 'add')
      successfullyAdded = successfullyAdded + 1
      print("^2[MNS-AIRDROPS]^7 Successfully gave item: " .. randItem)
      Wait(500)
    else
      print("^1[MNS-AIRDROPS]^7 Failed to add item " .. randItem .. " to player " .. src)
    end
  end
  
  -- Success notification with item count
  if successfullyAdded > 0 then
    -- Build item list for notification
    local itemList = table.concat(givenItems, ", ")
    local message = "You looted " .. successfullyAdded .. " items: " .. itemList
    
    -- Send detailed notification
    TriggerClientEvent('mns-airdrops:client:notification', src, message, "success", 7000)
    print("^2[MNS-AIRDROPS]^7 Player ID " .. src .. " looted " .. successfullyAdded .. " items: " .. itemList)
  else
    -- No items were added notification
    TriggerClientEvent('mns-airdrops:client:notification', src, 
                      "Couldn't add any items to your inventory", "error", 5000)
    print("^1[MNS-AIRDROPS]^7 Player ID " .. src .. " couldn't receive any items")
    
    -- If couldn't add items, allow player to try again
    lootedPlayers[src] = nil
  end
  
  -- Only start the cleanup timer once a successful loot has occurred
  -- AND only if we don't already have an active timer
  if successfullyAdded > 0 and not deleteTimerActive then
    deleteTimerActive = true
    
    CreateThread(function()
      -- The box will remain for the configured time regardless of looting
      Wait(Config.timetodeletebox * 60000)
      print("^3[MNS-AIRDROPS]^7 Deleting airdrop after timeout")
      
      -- Clean up and reset variables
      TriggerClientEvent("mns-airdrops:client:clearStuff", -1)
      looted = false
      lootedPlayers = {}
      deleteTimerActive = false
    end)
  end
end)

-- Add a general notification function for client
RegisterNetEvent('mns-airdrops:client:notify', function(message, type, duration)
  local src = source
  TriggerClientEvent('mns-airdrops:client:notification', src, message, type, duration)
end)

-- Callback for checking if airdrop was already looted by this specific player
lib.callback.register('mns-airdrops:server:getLootState', function(source)
  local src = source
  
  -- If not set up yet or not looted at all
  if not looted then
    return false
  end
  
  -- If no player tracking yet
  if not lootedPlayers then
    lootedPlayers = {}
    return false -- No one has looted yet
  end
  
  -- Return true if this player has already looted
  return lootedPlayers[src] or false
end)

-- Admin command with proper name from config and notification handling
QBCore.Commands.Add(Config.adminCommand.name, "Spawn a test airdrop (Admin Only)", {}, true, function(source)
  local src = source
  looted = false
  lootedPlayers = {}  -- Reset the player tracking
  deleteTimerActive = false -- Reset timer tracking
  TriggerClientEvent("mns-airdrops:client:clearStuff", -1)
  
  -- Choose a random location from config
  local randomloc = math.random(1, #Config.Locs)
  loc = Config.Locs[randomloc]
  cratePosition = loc
  
  -- Trigger airdrop event with admin test flag set to true
  TriggerClientEvent("mns-airdrops:client:adminTestAirdrop", -1, loc)
  
  -- Log to console
  print("^2[MNS-AIRDROPS]^7 Admin " .. GetPlayerName(src) .. " (ID: " .. src .. ") spawned a test airdrop at location: " .. loc.x .. ", " .. loc.y .. ", " .. loc.z)
end, Config.adminCommand.permission)

-- Test command to force give loot
QBCore.Commands.Add('testloot', 'Test Airdrop Loot (Admin)', {}, true, function(source)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then return end
    
    -- Give a few test items
    local testItems = {"weapon_pistol", "lockpick", "phone"}
    local successCount = 0
    
    for _, item in ipairs(testItems) do
        local success = Player.Functions.AddItem(item, 1)
        if success then
            successCount = successCount + 1
            TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[item], 'add')
        end
    end
    
    TriggerClientEvent('mns-airdrops:client:notification', src, 
                      "Test gave " .. successCount .. " of " .. #testItems .. " items", "success", 5000)
end, 'admin')

-- Version check event
CreateThread(function()
  Wait(5000) -- Wait for resource to fully initialize
  
  print("^2[MNS-AIRDROPS]^7 Server initialized successfully!")
  print("^2[MNS-AIRDROPS]^7 Next airdrop will occur in " .. Config.intervalBetweenAirdrops .. " minutes")
end)

-- Custom event for manually triggering an airdrop (for integration with other scripts)
RegisterServerEvent('mns-airdrops:server:triggerManualAirdrop', function(customLocation)
  -- Only allow this to be triggered from server-side scripts
  local src = source
  if src ~= 0 then return end
  
  -- Reset looted status and crate position
  looted = false
  lootedPlayers = {}  -- Reset the player tracking
  deleteTimerActive = false -- Reset timer tracking
  
  -- Notify clients to clean up
  TriggerClientEvent("mns-airdrops:client:clearStuff", -1)
  
  -- Use provided location or pick a random one
  local dropLocation = customLocation
  if not dropLocation then
    local randomloc = math.random(1, #Config.Locs)
    dropLocation = Config.Locs[randomloc]
  end
  
  loc = dropLocation
  cratePosition = loc
  -- Pass false to indicate this is not an admin test
  TriggerClientEvent("mns-airdrops:client:startAirdrop", -1, loc, false)
  
  -- Log to console
  print("^2[MNS-AIRDROPS]^7 Manual airdrop triggered at location: " .. loc.x .. ", " .. loc.y .. ", " .. loc.z)
end)
