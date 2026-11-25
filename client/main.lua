local PROMPT = 'vendrob'
local RANGE = 2.0
local SCAN_MS, NEAR_MS = 800, 300
local TOOL_MS = 2500

local near
local promptKey
local toolsAt, toolsHave = 0, false

local function startKey()
    local raw = GetControlInstructionalButton(0, joaat('+cortexvendrob_start') | 0x80000000, true)
    if type(raw) == 'string' and raw:sub(1, 2) == 't_' then return raw:sub(3) end
    return Config.Keys.start
end

local function carrying(item)
    if item == false then return true end
    local ok, count = pcall(function() return exports.ox_inventory:Search('count', item) end)
    return ok and (tonumber(count) or 0) > 0
end

local function hasTools()
    local now = GetGameTimer()
    if now - toolsAt < TOOL_MS then return toolsHave end
    toolsAt = now
    toolsHave = carrying(Config.Tools.pick) or carrying(Config.Tools.crowbar)
    return toolsHave
end

local function labelFor(c)
    local rec = World.get(c.id)
    local snap = rec and rec.snap
    local me = GetPlayerServerId(PlayerId())
    if snap and snap.worker and snap.worker ~= me then return nil end
    if c.mine then
        if snap and snap.stage ~= 'lock' then return L('prompt.repair'), 'repair' end
        return nil
    end
    if snap then
        if snap.stage == 'spent' then return nil end
        if snap.stage == 'open' then return L('prompt.resume'), 'begin' end
    elseif c.held then
        return nil
    end
    if not hasTools() then return nil end
    return L(snap and 'prompt.resume' or 'prompt.start'), 'begin'
end

local function hidePrompt()
    if not promptKey then return end
    promptKey = nil
    lib.hideInteraction(PROMPT)
end

local function showPrompt(c, label)
    local def = CxVendRob.Machines[c.type]
    local rec = World.get(c.id)
    local open = rec ~= nil and rec.snap.stage ~= 'lock'
    local at = open and GetOffsetFromEntityInWorldCoords(c.entity, 0.0, def.front - 0.03, 1.05)
        or GetOffsetFromEntityInWorldCoords(c.entity, def.lock.x, def.lock.y - 0.03, def.lock.z)
    local key = ('%s|%d|%s|%s'):format(label, c.id, startKey(), tostring(open))
    if promptKey == key then return end
    promptKey = key
    lib.showInteraction({
        id = PROMPT, label = label, key = startKey(), priority = 45,
        anchor = { type = 'world', x = at.x, y = at.y, z = at.z, maxDistance = RANGE + 0.4 },
    })
end

CreateThread(function()
    while true do
        local sleep = SCAN_MS
        local ped = PlayerPedId()
        if Rob.session or IsPedInAnyVehicle(ped, false) or IsEntityDead(ped) or IsPedCuffed(ped) then
            near = nil
            hidePrompt()
            sleep = 1000
        else
            local c = World.near(RANGE)
            local label, action
            if c then label, action = labelFor(c) end
            if label then
                c.action = action
                near = c
                showPrompt(c, label)
                sleep = NEAR_MS
            else
                near = nil
                hidePrompt()
            end
        end
        Wait(sleep)
    end
end)

AddEventHandler('onClientResourceStart', function(name)
    if name == 'cortex-lib' then promptKey = nil end
end)

local starting = false

local ERRORS = {
    invalid = 'begin.invalid', unfit = 'begin.unfit', busy = 'begin.busy', far = 'begin.far', spent = 'begin.spent', taken = 'begin.taken',
    cooldown = 'begin.cooldown', recent = 'begin.recent', police = 'begin.police', tool = 'begin.tool', offline = 'begin.offline',
    off = 'begin.off', own = 'begin.own', away = 'begin.away', tray = 'begin.tray', inuse = 'begin.inuse', cash = 'repair.cash',
}

local function refuse(result)
    local key = ERRORS[result.error] or 'begin.invalid'
    local arg = result.minutes or result.needed or result.tool or result.cost
    Rob.notify('error', arg ~= nil and L(key, arg) or L(key))
end

local function begin(c)
    if starting or Rob.session then return end
    starting = true
    local result = Rob.await(c.action == 'repair' and 'repair' or 'begin', c.id)
    starting = false
    if type(result) ~= 'table' then return end
    if not result.ok then return refuse(result) end
    if c.action == 'repair' then
        return Rob.notify('success', L('repair.done', Rob.money(result.cost or 0)))
    end
    local snap = result.machine
    World.apply(snap.id, snap)
    local rec = World.get(snap.id)
    if not rec then
        TriggerServerEvent('cortex-vendrobbery:server:leave')
        return
    end
    Session.start(rec, result.lock, result.tools or {})
end

RegisterCommand('+cortexvendrob_start', function()
    if Rob.session or not near then return end
    if not lib.isInteractionActive(PROMPT) then return end
    local c = near
    CreateThread(function() begin(c) end)
end, false)
RegisterCommand('-cortexvendrob_start', function() end, false)
RegisterKeyMapping('+cortexvendrob_start', L('keymap.start'), 'keyboard', Config.Keys.start)

local SOUNDS = { pin = 'set', pop = 'pop', clang = 'clang', lockout = 'lockout', drill = 'drill', grab = 'grab' }

RegisterNetEvent('cortex-vendrobbery:client:effect', function(id, kind)
    local rec = World.get(id)
    if not rec then return end
    if Rob.session and Rob.session.id == id then return end
    local at = rec.at + vector3(0.0, 0.0, 1.0)
    if SOUNDS[kind] then Fx.sound(SOUNDS[kind], at) end
    if kind == 'drill' or kind == 'lockout' then Fx.sparks(at, 0.2) end
end)
