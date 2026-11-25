local TAB = 'cortex-vendrobbery'

local function read(key)
    local ok, value = pcall(function() return exports['cortex-lib']:getTabSetting(TAB, key) end)
    if ok then return value end
    return nil
end

local function refresh()
    local light = read('workLight')
    if type(light) == 'boolean' then Camera.setLight(light) end
end

local function register()
    if GetResourceState('cortex-lib') ~= 'started' then return end
    local ok, registered = pcall(function()
        return exports['cortex-lib']:registerSettings(TAB, L('settings.tab'), 'cortex-vendrobbery:', {
            { key = 'workLight', type = 'toggle', label = L('settings.light'), description = L('settings.light_desc'), default = true },
        }, {
            workLight = true,
        }, { group = 'Activities' })
    end)
    if ok and registered then refresh() end
end

AddEventHandler('cortex-lib:settingsChanged', function(tabId)
    if tabId == TAB then refresh() end
end)

AddEventHandler('onClientResourceStart', function(resource)
    if resource == 'cortex-lib' then register() end
end)

CreateThread(register)
