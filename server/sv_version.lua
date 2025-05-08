-- Version Check System for mns-airdrops
local resourceName = GetCurrentResourceName()
local currentVersion = GetResourceMetadata(resourceName, 'version', 0)
local repositoryUrl = 'https://github.com/mooons9992/mns-airdrops'
local versionCheckEndpoint = 'https://raw.githubusercontent.com/mooons9992/mns-airdrops/main/version.json'
local versionCheckDone = false

-- Format console output with colors and better styling
local function PrintVersionInfo(outdated, currentVer, latestVer, changelog)
    -- Only print once
    if versionCheckDone then return end
    versionCheckDone = true
    
    print('')
    print('^8╔═══════════════════════════════════════════════════════════════════════╗^0')
    print('^8║                         ^5MNS AIRDROPS VERSION CHECK                     ^8║^0')
    print('^8╠═══════════════════════════════════════════════════════════════════════╣^0')
    
    if outdated then
        print('^8║ ^1VERSION MISMATCH DETECTED!                                          ^8║^0')
        print('^8║ ^1Your version:  ' .. string.rep(' ', 20 - #currentVer) .. currentVer .. string.rep(' ', 31) .. '^8║^0')
        print('^8║ ^2Latest version:' .. string.rep(' ', 20 - #latestVer) .. latestVer .. string.rep(' ', 31) .. '^8║^0')
        
        if changelog then
            local changelogLines = SplitString(changelog, 50)
            print('^8║ ^3CHANGELOG:                                                         ^8║^0')
            for _, line in ipairs(changelogLines) do
                print('^8║ ^3' .. line .. string.rep(' ', 53 - #line) .. '^8║^0')
            end
        end
        
        print('^8║                                                                   ^8║^0')
        print('^8║ ^3Please update from: ^5' .. repositoryUrl .. '^8        ║^0')
    else
        print('^8║ ^2You are running the latest version of MNS Airdrops.                ^8║^0')
        print('^8║ ^2Version: ' .. currentVer .. string.rep(' ', 45 - #currentVer) .. '^8║^0')
    end
    
    print('^8╚═══════════════════════════════════════════════════════════════════════╝^0')
    print('')
end

-- Split long text into multiple lines
function SplitString(str, maxLength)
    local result = {}
    local line = ""
    
    for word in str:gmatch("%S+") do
        if #line + #word + 1 > maxLength then
            table.insert(result, line)
            line = word
        else
            line = #line == 0 and word or line .. " " .. word
        end
    end
    
    if #line > 0 then
        table.insert(result, line)
    end
    
    return result
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
        
        -- Compare versions
        local outdated = versionData.version ~= currentVersion
        PrintVersionInfo(outdated, currentVersion, versionData.version, versionData.changelog)
        
    end, 'GET', '', { ['Content-Type'] = 'application/json' })
end

-- Run version check when resource starts
CreateThread(function()
    Wait(3000) -- Wait 3 seconds after server startup
    CheckVersion()
end)