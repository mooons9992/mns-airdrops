return {
   intervalBetweenAirdrops = 20, --time in minutes

   progressbarDuration = 10000, -- milliseconds
   
   -- UI framework configuration
   UI = {
      inventory = 'qb', -- Options: 'qb', 'ox'
      progressBar = 'ox', -- Options: 'qb', 'ox'
      notification = 'qb', -- Options: 'qb', 'ox', 'custom'
      target = 'ox', -- Options: 'qb', 'ox'
   },
   
   -- Sound configuration
   sounds = {
      incoming = {
         soundName = 'Mission_Pass_Notify',
         soundDict = 'DLC_HEISTS_GENERAL_FRONTEND_SOUNDS',
         maxDistance = 1000.0, -- Only play sound if player is within this distance (in meters)
      },
      plane = {
         soundName = 'Flying_By',
         soundDict = 'MP_MISSION_COUNTDOWN_SOUNDSET',
         maxDistance = 600.0,
      },
      crate = {
         soundName = 'Crate_Beeps',
         soundDict = 'MP_CRATE_DROP_SOUNDS',
         maxDistance = 150.0,
         interval = 5000, -- Milliseconds between beacon sounds
      },
   },

   -- Notification templates
   notifications = {
      airdropIncoming = {
         message = "Airdrop incoming!", 
         type = "primary", -- primary, success, error, info
         duration = 5000,
      },
      alreadyLooted = {
         message = "This was already looted or being looted",
         type = "error",
         duration = 3000,
      },
      lootReceived = {
         message = "You have successfully looted the airdrop",
         type = "success",
         duration = 4000,
      },
   },

   --locations here can airdrops drop
   Locs = {
      vec3(266.44, 2043.73, 122.75),
      vec3(191.6, 2240.89, 88.97),
      vec3(-188.84, 2244.0, 118.63),
   },

   AirCraft = {
      PilotModel = "s_m_m_pilot_01", -- Pilot model
      PlaneModel = "titan", -- Plane model
      Height = 450.0, -- Plane Height
      Speed = 92.0, -- Plane Speed
   },

   --location here aircraft can spawn
   aircraftSpawnPoint = vec3(3562.5, 1356.43, 450.0),
   
   --location where aircraft despawns after dropping cargo
   aircraftDespawnPoint = vec3(-2194.32, 5120.9, 450.0),

   -- Blip configuration
   blips = {
      airdrop = {
         sprite = 550,
         scale = 0.7,
         color = 1,
         name = "Air Drop"
      },
      radius = {
         size = 120.0,
         color = 1,
         alpha = 80
      },
      plane = {
         sprite = 307
      }
   },
   
   -- Flare effect configuration
   flare = {
      asset = "scr_biolab_heist",
      effect = "scr_heist_biolab_flare",
   },

   --items that you can get in airdrop
   LootTable = {
      "weapon_combatpistol",
      "weapon_assaultrifle",
      "weapon_smg",
      "weapon_heavypistol",
      "weapon_carbinerifle",
      "weapon_machinepistol",
      "weapon_pistol",
   },

   -- Range for random item count
   -- Can be a single number or a table with min/max values
   amountOfItems = {4, 5}, --amount of items you can get in airdrop

   timetodeletebox = 0.2, --time to delete the airdrop after looted in minutes

   falldownSpeed = 0.1, -- you can set it like 0.01 to get very slow you 0.2 to get faster
   
   -- Admin command settings
   adminCommand = {
      name = "testairdrop",
      permission = "admin" -- Permission level required
   },
   
   -- Distance thresholds
   distances = {
      notificationRange = 1500.0, -- Only notify players within this range
      planeDeleteDistance = 2000.0, -- Delete plane when this far from drop point
      lootingDistance = 10.0, -- Max distance for looting (anti-cheat check)
   }
}