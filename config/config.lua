return {
   intervalBetweenAirdrops = 20, --time in minutes

   progressbarDuration = 10000, -- milliseconds
   
   -- UI framework configuration
   UI = {
      inventory = 'ps', -- Options: 'qb', 'ox'
      progressBar = 'qb', -- Options: 'qb', 'ox'
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
         soundName = '', -- Disabled beeping sound by setting to empty string
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
      -- New notification for admin test command
      adminTest = {
         message = "Admin test airdrop initiated!",
         type = "primary",
         duration = 5000,
      },
      -- New notifications
      inventoryFull = {
         message = "Your inventory is full, make some space first",
         type = "error",
         duration = 3000,
      },
      itemAddFailed = {
         message = "Failed to add some items to your inventory",
         type = "error",
         duration = 3000,
      }
   },

   --locations here can airdrops drop
   Locs = {
      -- Original locations
      vec3(266.44, 2043.73, 122.75),
      vec3(191.6, 2240.89, 88.97),
      vec3(-188.84, 2244.0, 118.63),
      
      -- 15 additional locations spread across the map
      -- Sandy Shores / Grand Senora Desert area
      vec3(1551.42, 3789.35, 34.05),    -- Sandy Shores Airfield
      vec3(2482.51, 3722.77, 43.92),    -- Sandy Shores gas station area
      vec3(1322.43, 3089.48, 40.29),    -- Grand Senora Desert
      
      -- Paleto Bay area
      vec3(-276.45, 6239.56, 31.49),    -- Paleto Bay lumber mill
      vec3(-91.59, 6496.58, 31.49),     -- Paleto Bay beach
      vec3(-712.68, 5783.21, 17.71),    -- Procopio Beach
      
      -- Mount Chiliad region
      vec3(501.34, 5604.52, 795.73),    -- Mount Chiliad summit
      vec3(2784.08, 5994.13, 354.87),   -- Mount Gordo
      
      -- Zancudo & Chumash area
      vec3(-2096.77, 3074.56, 32.81),   -- Fort Zancudo outskirts
      vec3(-3032.45, 3668.88, 11.03),   -- Chumash beach
      
      -- Los Santos city outskirts
      vec3(2209.82, 1081.29, 77.32),    -- Grand Senora Highway
      vec3(1200.89, -1259.83, 35.23),   -- La Mesa
      vec3(988.39, -2529.62, 28.30),    -- Los Santos International Airport
      vec3(-1083.21, -1606.87, 4.65),   -- Vespucci Beach
      
      -- Far north wilderness
      vec3(-1594.83, 4760.79, 62.35),   -- North coastline
      
      -- Far east wilderness 
      vec3(2954.16, 2768.25, 39.12),    -- Grand Senora Desert east
      vec3(2884.47, 4862.74, 62.66),    -- Grapeseed farmland
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

   -- Crate model configuration
   crateModel = "gr_prop_gr_crates_guns_01a", -- Military crate with visible weapons
   
   -- Fallback models if primary fails to load (in order of preference)
   fallbackModels = {
      "prop_box_ammo04a",       -- Simple ammo box (loads reliably)
      "prop_mil_crate_01",      -- Basic military crate (loads quickly)
      "ex_prop_crate_ammo_sc",  -- Ammo supply crate
      "prop_drop_armscrate_01"  -- Default airdrop crate
   },

   -- Model loading settings
   modelLoadTimeout = 5000,     -- Milliseconds to wait for model to load (5 seconds)

   -- Optional alternate models (commented out):
   -- "gr_prop_gr_rsply_crate04a" -- Large gunrunning supply crate
   -- "prop_mil_crate_01" -- Military crate
   -- "ex_prop_crate_ammo_sc" -- Ammunition crate

   -- Visual effects
   enableParachuteEffect = false, -- Add parachute to crate when falling
   enableSmokeOnLand = true, -- Add smoke effect when crate lands

   -- Double-check your loot table has valid items

   --items that you can get in airdrop
   LootTable = {
      "weapon_combatpistol",
      "weapon_assaultrifle",
      "weapon_smg",
      "weapon_heavypistol",
      "weapon_carbinerifle",
      "weapon_machinepistol",
      "weapon_pistol",
      -- Add some non-weapon items as fallbacks
      "lockpick",
      "phone",
      "radio",
   },

   -- Range for random item count
   -- Can be a single number or a table with min/max values
   amountOfItems = {4, 5}, --amount of items you can get in airdrop

   timetodeletebox = 0.2, --time to delete the airdrop after looted in minutes

   falldownSpeed = 0.15, -- Slightly faster fall for military crates
   
   -- Admin command settings
   adminCommand = {
      name = "testairdrop",
      permission = "admin", -- Permission level required
      forceNotification = true -- Always show notification for admin test airdrops
   },
   
   -- Distance thresholds
   distances = {
      notificationRange = 1500.0, -- Only notify players within this range
      planeDeleteDistance = 2000.0, -- Delete plane when this far from drop point
      lootingDistance = 10.0, -- Max distance for looting (anti-cheat check)
   }
}