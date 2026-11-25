Rob = {
    resource = GetCurrentResourceName(),
    records = {},
    session = nil,
}

function Rob.notify(kind, text, title)
    lib.notify({ type = kind, title = title, description = text, sender = 'cortex-vendrobbery' })
end

function Rob.money(n)
    local digits = tostring(math.floor(tonumber(n) or 0))
    local out = digits:reverse():gsub('(%d%d%d)', '%1,'):reverse():gsub('^,', '')
    return '$' .. out
end

function Rob.await(name, ...)
    return lib.callback.await('cortex-vendrobbery:' .. name, false, ...)
end

local loading = {}

function Rob.model(name)
    local hash = type(name) == 'number' and name or joaat(name)
    if HasModelLoaded(hash) then return hash end
    if not IsModelInCdimage(hash) then return nil end
    RequestModel(hash)
    loading[hash] = true
    local deadline = GetGameTimer() + 8000
    while not HasModelLoaded(hash) do
        if GetGameTimer() > deadline then return nil end
        Wait(0)
    end
    return hash
end

function Rob.ready(name)
    local hash = type(name) == 'number' and name or joaat(name)
    if HasModelLoaded(hash) then return true end
    if not IsModelInCdimage(hash) then return nil end
    RequestModel(hash)
    loading[hash] = true
    return false
end

function Rob.spawn(name, at)
    local hash = Rob.model(name)
    if not hash then return nil end
    local obj = CreateObjectNoOffset(hash, at.x, at.y, at.z, false, false, false)
    if obj == 0 then return nil end
    SetEntityCollision(obj, false, false)
    SetEntityInvincible(obj, true)
    FreezeEntityPosition(obj, true)
    SetEntityAsMissionEntity(obj, true, true)
    return obj
end

function Rob.delete(obj)
    if obj and obj ~= 0 and DoesEntityExist(obj) then
        if IsEntityAttached(obj) then DetachEntity(obj, false, false) end
        SetEntityAsMissionEntity(obj, true, true)
        DeleteEntity(obj)
    end
end

function Rob.loadDict(dict)
    if HasAnimDictLoaded(dict) then return true end
    RequestAnimDict(dict)
    local deadline = GetGameTimer() + 2000
    while not HasAnimDictLoaded(dict) and GetGameTimer() < deadline do Wait(0) end
    return HasAnimDictLoaded(dict)
end

function Rob.loadPtfx(asset)
    if HasNamedPtfxAssetLoaded(asset) then return true end
    RequestNamedPtfxAsset(asset)
    local deadline = GetGameTimer() + 2000
    while not HasNamedPtfxAssetLoaded(asset) and GetGameTimer() < deadline do Wait(0) end
    return HasNamedPtfxAssetLoaded(asset)
end

CreateThread(function()
    pcall(function() lib.registerSender('cortex-vendrobbery', { label = L('title'), color = '#e0a23a', icon = 'V' }) end)
end)

AddEventHandler('onResourceStop', function(name)
    if name ~= Rob.resource then return end
    for hash in pairs(loading) do SetModelAsNoLongerNeeded(hash) end
end)
