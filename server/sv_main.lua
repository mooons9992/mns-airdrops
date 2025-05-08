local Config = require 'config.config'
local QBCore = exports['qb-core']:GetCoreObject()

local waitTime = Config.intervalBetweenAirdrops * 60000
local loc = nil
local looted = false

CreateThread(function()
  while true do
      Wait(waitTime)
      looted = false
      TriggerClientEvent("mns-airdrops:client:clearStuff", -1)
      local randomloc = math.random(1, #Config.Locs)
      loc = Config.Locs[randomloc]  
      TriggerClientEvent("mns-airdrops:client:startAirdrop", -1, loc)
  end
end)

RegisterNetEvent("mns-airdrops:server:sync:loot", function()
  looted = true
end)

RegisterNetEvent("mns-airdrops:server:getLoot", function()
  local src = source
  if not looted then return end
  if #(loc - GetEntityCoords(GetPlayerPed(src))) > 10 then 
    DropPlayer(src, "Exploit attempt detected") 
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
  
  -- Success notification
  QBCore.Functions.Notify(src, "You have successfully looted the airdrop", "success", 4000)
  
  -- Delete box after configured time
  Wait(Config.timetodeletebox * 60000)
  TriggerClientEvent("mns-airdrops:client:clearStuff", -1)
end)

lib.callback.register('mns-airdrops:server:getLootState', function()
  return looted
end)

-- Admin command with proper name
QBCore.Commands.Add("testairdrop", "Spawn a test airdrop (Admin Only)", {}, true, function(source)
  local src = source
  looted = false
  TriggerClientEvent("mns-airdrops:client:clearStuff", -1)
  local randomloc = math.random(1, #Config.Locs)
  loc = Config.Locs[randomloc]    
  
  TriggerClientEvent("mns-airdrops:client:startAirdrop", -1, loc)
end, "admin")
