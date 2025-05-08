-- Version Check System for mns-airdrops
local resourceName = GetCurrentResourceName()
local currentVersion = GetResourceMetadata(resourceName, 'version', 0)
local repositoryUrl = 'https://github.com/mooons9992/mns-airdrops'
local versionCheckEndpoint = 'https://raw.githubusercontent.com/mooons9992/mns-airdrops/main/version.json'
local versionCheckDone = false

-- Simple version check function
local function CheckVersion()
    -- Only run once
    if versionCheckDone then return end
    
    PerformHttpRequest(versionCheckEndpoint, function(errorCode, resultData, resultHeaders)
        -- Mark as done immediately to prevent duplicate calls
        versionCheckDone = true
        
        if errorCode ~= 200 then
            print('^1[' .. resourceName .. '] Failed to check version^7')
            return
        end

        local versionData = json.decode(resultData)
        if not versionData or not versionData.version then
            print('^1[' .. resourceName .. '] Invalid version data^7')
            return
        end
        
        -- Simple output in a single line
        if versionData.version ~= currentVersion then
            -- Outdated version - show in red
            print('^1[\'' .. resourceName .. '\'] - You are running an outdated version!^7')
            print('^3[UPDATE] ' .. repositoryUrl .. '^7')
        else
            -- Latest version - show in green
            print('^2[\'' .. resourceName .. '\'] - You are running the latest version. (' .. currentVersion .. ')^7')
        end
    end, 'GET', '', { ['Content-Type'] = 'application/json' })
end

-- The proper way to ensure it only runs once when resource starts
local hasChecked = false
Citizen.CreateThread(function()
    if hasChecked then return end
    hasChecked = true
    
    -- Wait a moment for server to initialize
    Citizen.Wait(5000)
    CheckVersion()
end)