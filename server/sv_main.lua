local Config = require 'config.config'
local QBCore = exports['qb-core']:GetCoreObject()

local waitTime = Config.intervalBetweenAirdrops * 60000
local loc = nil
local looted = false

-- Regular airdrops on the configured interval
CreateThread(function()
  while true do
      Wait(waitTime)
      looted = false
      TriggerClientEvent("mns-airdrops:client:clearStuff", -1)
      local randomloc = math.random(1, #Config.Locs)
      loc = Config.Locs[randomloc]  
      -- Pass false to indicate this is not an admin test
      TriggerClientEvent("mns-airdrops:client:startAirdrop", -1, loc, false)
      
      -- Log to console
      print("^2[MNS-AIRDROPS]^7 Airdrop started at location: " .. loc.x .. ", " .. loc.y .. ", " .. loc.z)
  end
end)

-- Sync looting state between players
RegisterNetEvent("mns-airdrops:server:sync:loot", function()
  looted = true
end)

-- Handle player getting loot
RegisterNetEvent("mns-airdrops:server:getLoot", function()
  local src = source
  if not looted then return end
  
  -- Anti-cheat distance check
  local maxDistance = Config.distances and Config.distances.lootingDistance or 10.0
  if #(loc - GetEntityCoords(GetPlayerPed(src))) > maxDistance then 
    DropPlayer(src, "Exploit attempt detected") 
    print("^1[MNS-AIRDROPS]^7 Player ID " .. src .. " attempted to exploit airdrop loot from distance")
    return 
  end
  
  local Player = QBCore.Functions.GetPlayer(src)
  
  -- Determine number of items to give
  local amountOfItems = Config.amountOfItems
  if type(amountOfItems) == "table" then
    amountOfItems = math.random(amountOfItems[1], amountOfItems[2])
  end
  
  -- Give items
  for i = 1, amountOfItems do
    local randItem = Config.LootTable[math.random(1, #Config.LootTable)]
    Player.Functions.AddItem(randItem, 1)
    TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[randItem], 'add')
    Wait(500)
  end
  
  -- Success notification - uses client-side notification system
  TriggerClientEvent("mns-airdrops:client:lootSuccessful", src)
  
  -- Log to server console
  print("^2[MNS-AIRDROPS]^7 Player ID " .. src .. " looted airdrop")
  
  -- Delete box after configured time
  Wait(Config.timetodeletebox * 60000)
  TriggerClientEvent("mns-airdrops:client:clearStuff", -1)
end)

-- Callback for checking if airdrop was already looted
lib.callback.register('mns-airdrops:server:getLootState', function()
  return looted
end)

-- Admin command with proper name from config and notification handling
QBCore.Commands.Add(Config.adminCommand.name, "Spawn a test airdrop (Admin Only)", {}, true, function(source)
  local src = source
  looted = false
  TriggerClientEvent("mns-airdrops:client:clearStuff", -1)
  
  -- Choose a random location from config
  local randomloc = math.random(1, #Config.Locs)
  loc = Config.Locs[randomloc]
  
  -- Trigger airdrop event with admin test flag set to true
  TriggerClientEvent("mns-airdrops:client:adminTestAirdrop", -1, loc)
  
  -- Log to console
  print("^2[MNS-AIRDROPS]^7 Admin " .. GetPlayerName(src) .. " (ID: " .. src .. ") spawned a test airdrop at location: " .. loc.x .. ", " .. loc.y .. ", " .. loc.z)
end, Config.adminCommand.permission)

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
  
  looted = false
  TriggerClientEvent("mns-airdrops:client:clearStuff", -1)
  
  -- Use provided location or pick a random one
  local dropLocation = customLocation
  if not dropLocation then
    local randomloc = math.random(1, #Config.Locs)
    dropLocation = Config.Locs[randomloc]
  end
  
  loc = dropLocation
  -- Pass false to indicate this is not an admin test
  TriggerClientEvent("mns-airdrops:client:startAirdrop", -1, loc, false)
  
  -- Log to console
  print("^2[MNS-AIRDROPS]^7 Manual airdrop triggered at location: " .. loc.x .. ", " .. loc.y .. ", " .. loc.z)
end)
