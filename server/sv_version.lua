-- Version Check System for mns-airdrops
local resourceName = GetCurrentResourceName()
local currentVersion = GetResourceMetadata(resourceName, 'version', 0)
local repositoryUrl = 'https://github.com/mooons9992/mns-airdrops'
local versionCheckEndpoint = 'https://raw.githubusercontent.com/mooons9992/mns-airdrops/main/version.json'

-- Display formatted header
local function PrintVersionHeader()
    print(' ----------------------------------------------------------------------')
end

-- Check version against GitHub
local function CheckVersion()
    PerformHttpRequest(versionCheckEndpoint, function(errorCode, resultData, resultHeaders)
        if errorCode ~= 200 then
            print('^1[' .. resourceName .. '] Failed to check version - Error: ' .. tostring(errorCode) .. '^7')
            return
        end

        local versionData = json.decode(resultData)
        if not versionData or not versionData.version then
            print('^1[' .. resourceName .. '] Invalid version data received from GitHub^7')
            return
        end

        PrintVersionHeader()
        
        -- Compare versions
        if versionData.version ~= currentVersion then
            print('^1[   script:' .. resourceName .. '] \'' .. resourceName .. '\' - You are running an outdated version! (' .. currentVersion .. ' → ' .. versionData.version .. ')^7')
            
            -- If there's a specific changelog note, display it
            if versionData.changelog then
                print('^3[   script:' .. resourceName .. '] Update notes: ' .. versionData.changelog .. '^7')
            end
            
            print('^3[   script:' .. resourceName .. '] Please update from: ' .. repositoryUrl .. '^7')
        else
            print('^2[   script:' .. resourceName .. '] \'' .. resourceName .. '\' - You are running the latest version. (' .. currentVersion .. ')^7')
        end
        
        PrintVersionHeader()
    end, 'GET', '', { ['Content-Type'] = 'application/json' })
end

-- Run version check when resource starts
CreateThread(function()
    Wait(5000) -- Wait 5 seconds after server startup
    CheckVersion()
end)