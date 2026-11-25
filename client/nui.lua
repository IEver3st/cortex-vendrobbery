Nui = { ready = false, focused = false }

local queue = {}
local last = {}
local DEDUPE = { targets = true, hover = true, gauge = true, tools = true, stage = true, strikes = true, notebook = true }

local function rounded(v)
    if type(v) == 'number' then return math.floor(v * 1000 + 0.5) / 1000 end
    if type(v) ~= 'table' then return v end
    local out = {}
    for k, x in pairs(v) do out[k] = rounded(x) end
    return out
end

function Nui.send(msg)
    if DEDUPE[msg.type] then
        msg = rounded(msg)
        local encoded = json.encode(msg)
        if last[msg.type] == encoded then return end
        last[msg.type] = encoded
    end
    if not Nui.ready then
        if msg.type ~= 'sound' and msg.type ~= 'alarm' and #queue < 64 then queue[#queue + 1] = msg end
        return
    end
    SendNUIMessage(msg)
end

function Nui.reset()
    last = {}
end

function Nui.focus(on)
    if Nui.focused == on then return end
    Nui.focused = on
    SetNuiFocus(on, on)
    SetNuiFocusKeepInput(false)
end

RegisterNUICallback('ready', function(_, cb)
    cb({ ok = true })
    Nui.ready = true
    SendNUIMessage({ type = 'locale', strings = LocaleGroup('hud.') })
    for _, msg in ipairs(queue) do SendNUIMessage(msg) end
    queue = {}
end)

RegisterNUICallback('input', function(data, cb)
    cb({ ok = true })
    if type(data) ~= 'table' then return end
    if Session and Session.input then Session.input(data) end
end)

AddEventHandler('onResourceStop', function(name)
    if name ~= Rob.resource then return end
    pcall(SetNuiFocus, false, false)
end)
