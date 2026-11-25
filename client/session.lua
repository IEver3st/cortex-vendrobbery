Session = {}

local WORK_DICT, WORK_CLIP = 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@', 'machinic_loop_mechandplayer'
local STAND_BACK = 0.72

local function module(s)
    if s.stage == 'lock' then return s.tool == 'crowbar' and Pry or Pick end
    if s.stage == 'open' then return s.tool == 'pick' and Pick or Open end
    return nil
end

function Session.toolList(s)
    local snap, have = s.rec.snap, s.have
    local list = {}
    local function add(id, locked)
        list[#list + 1] = { id = id, key = tostring(#list + 1), label = L('tool.' .. id), locked = locked or false }
    end
    if s.stage == 'lock' then
        add('pick', not have.pick or snap.jammed)
        add('crowbar', not have.crowbar)
    elseif s.stage == 'open' then
        if snap.stacker >= 0 then add('stacker', snap.stacker ~= 0) end
        if snap.box == 0 then
            add('pick', not have.pick or snap.seized)
            add('drill', not have.drill or snap.seized)
        else
            add('drawer', snap.box ~= 1)
        end
        if s.rec.def.shelves then add('shelves', (snap.shelfLeft or 0) <= 0) end
    end
    return list
end

local function usable(list, tool)
    for _, t in ipairs(list) do
        if t.id == tool then return not t.locked end
    end
    return false
end

local function legend(s)
    local m = module(s)
    if not m then return lib.hideHelp() end
    lib.showHelp(m.help(s), { compact = true })
end

function Session.notebook(s)
    local rows = {}
    for i = 1, CxVendRob.PinCount do
        rows[i] = { pin = i, depth = s.rec.notes[i] or false, set = s.rec.snap.pins[i] or false, box = i <= CxVendRob.BoxPins }
    end
    Nui.send({ type = 'notebook', rows = rows })
end

local function hudStage(s)
    local key = s.stage == 'lock' and (s.tool == 'crowbar' and 'pry' or 'pick') or (s.tool or 'open')
    Nui.send({ type = 'stage', stage = s.stage .. ':' .. key, hint = L('hint.' .. key), machine = L(s.rec.def.label) })
end

local function hudStrikes(s, flash)
    Nui.send({ type = 'strikes', count = s.rec.snap.strikes, max = Config.Strikes, flash = flash and GetGameTimer() or 0 })
end

local function refresh(s)
    Nui.send({ type = 'tools', list = Session.toolList(s), active = s.tool or false })
    hudStage(s)
    legend(s)
end

local function switch(s, stage, tool)
    local before = module(s)
    if before and before.exit then pcall(before.exit, s) end
    s.stage, s.tool, s.hover = stage, tool, nil
    local after = module(s)
    if after and after.enter then after.enter(s) end
    Camera.stage(after and after.view(s) or 'open')
    refresh(s)
end

local function firstTool(s, stage)
    local probe = { rec = s.rec, have = s.have, stage = stage }
    for _, t in ipairs(Session.toolList(probe)) do
        if not t.locked then return t.id end
    end
    return nil
end

function Session.select(s, tool)
    if tool == s.tool then return end
    if not usable(Session.toolList(s), tool) then
        Fx.sound('locked')
        return
    end
    Fx.sound('tool')
    switch(s, s.stage, tool)
end

local function standPoint(rec)
    local at = World.point(rec, 0.12, rec.def.front - STAND_BACK, 0.0)
    return at, rec.snap.heading % 360.0
end

local function pose(s)
    local ped = PlayerPedId()
    local at, heading = standPoint(s.rec)
    local pos = GetEntityCoords(ped)
    if #(vector2(pos.x, pos.y) - vector2(at.x, at.y)) > 0.3 then
        TaskGoStraightToCoord(ped, at.x, at.y, pos.z, 1.0, 2000, heading, 0.1)
        local deadline = GetGameTimer() + 2200
        while GetGameTimer() < deadline and Rob.session == s do
            local now = GetEntityCoords(ped)
            if #(vector2(now.x, now.y) - vector2(at.x, at.y)) <= 0.25 then break end
            Wait(50)
        end
    end
    if Rob.session ~= s then return end
    ClearPedTasks(ped)
    SetEntityHeading(ped, heading)
    if Rob.loadDict(WORK_DICT) then TaskPlayAnim(ped, WORK_DICT, WORK_CLIP, 3.0, 3.0, -1, 1, 0.0, false, false, false) end
end

local function hud(visible)
    if GetResourceState('cortex-hud') ~= 'started' then return end
    pcall(function()
        if visible then exports['cortex-hud']:showHud(Rob.resource) else exports['cortex-hud']:hideHud(Rob.resource) end
    end)
end

function Session.active() return Rob.session ~= nil end

function Session.finish(reason)
    local s = Rob.session
    if not s or s.closing then return end
    s.closing = true
    local m = module(s)
    if m and m.exit then pcall(m.exit, s) end
    Tools.dropAll()
    Rob.session = nil
    Nui.send({ type = 'session', open = false })
    Nui.focus(false)
    lib.hideHelp()
    Camera.exit(reason == 'stopped')
    hud(true)
    ClearPedTasks(PlayerPedId())
    TriggerServerEvent('cortex-vendrobbery:server:leave')
end

local function tooFar(s)
    local ped = PlayerPedId()
    if IsEntityDead(ped) or IsPedRagdoll(ped) or IsPedInAnyVehicle(ped, false) or IsPedCuffed(ped) then return true end
    return #(GetEntityCoords(ped) - s.rec.at) > CxVendRob.Reach
end

local function loop(s)
    CreateThread(function()
        while Rob.session == s do
            if tooFar(s) then return Session.finish('distance') end
            if not World.parts(s.rec) then return Session.finish('removed') end
            local nx, ny = Pointer.pos()
            Camera.sway(nx, ny)
            DisableAllControlActions(0)
            if GetGameTimer() >= (Camera.readyAt or 0) and not s.ending then
                local m = module(s)
                if m then
                    local ok, err = pcall(m.frame, s, nx, ny)
                    if not ok then print(('^1[cortex-vendrobbery]^7 %s frame: %s'):format(tostring(s.tool), tostring(err))) end
                end
            end
            Wait(0)
        end
    end)
end

function Session.start(rec, lock, have)
    if Rob.session then return end
    if not World.parts(rec, true) then
        TriggerServerEvent('cortex-vendrobbery:server:leave')
        return Rob.notify('error', L('begin.assets'))
    end
    local s = { id = rec.id, rec = rec, lock = lock, have = have, stage = nil, tool = nil }
    Rob.session = s
    Nui.reset()
    Nui.send({ type = 'session', open = true, machine = L(rec.def.label) })
    Nui.focus(true)
    hud(false)
    CreateThread(function()
        pose(s)
        if Rob.session ~= s then return end
        local stage = rec.snap.stage
        s.stage, s.tool = stage, firstTool(s, stage)
        if not s.tool then
            Rob.notify('inform', L(stage == 'lock' and 'end.locked' or 'end.nothing'))
            return Session.finish('done')
        end
        local m = module(s)
        Camera.enter(rec, m and m.view(s) or 'open')
        if m and m.enter then m.enter(s) end
        refresh(s)
        hudStrikes(s, false)
        Session.notebook(s)
        Nui.send({ type = 'alarmHud', seconds = math.ceil(Fx.alarmLeft(rec.id) / 1000) })
        loop(s)
    end)
end

local function ending(s, key, kind, ...)
    s.ending = true
    local m = module(s)
    if m and m.exit then pcall(m.exit, s) end
    Nui.send({ type = 'hover', label = false, status = false })
    Nui.send({ type = 'gauge', gauge = false })
    lib.hideHelp()
    Rob.notify(kind, L(key, ...))
    SetTimeout(1400, function() if Rob.session == s then Session.finish('done') end end)
end

function Session.updated(rec, old)
    local s = Rob.session
    if not s or s.rec ~= rec or s.ending or not s.stage then return end
    local snap = rec.snap
    if old and snap.strikes ~= old.strikes then hudStrikes(s, true) end
    Nui.send({ type = 'alarmHud', seconds = math.ceil(Fx.alarmLeft(rec.id) / 1000) })
    Session.notebook(s)
    if snap.stage == 'spent' then
        Fx.frontend('ROBBERY_MONEY_TOTAL', 'HUD_FRONTEND_CUSTOM_SOUNDSET')
        return ending(s, 'end.spent', 'success', Rob.money(snap.paid))
    end
    if old and snap.jammed and not old.jammed then Rob.notify('error', L('pick.jammed')) end
    if old and snap.seized and not old.seized then Rob.notify('error', L('box.seized')) end
    if snap.stage ~= s.stage then
        if snap.stage == 'open' then
            Fx.sound('open', rec.at)
            Rob.notify('success', L(snap.route == 'pry' and 'open.pry' or 'open.pick'))
        end
        local tool = firstTool(s, snap.stage)
        if not tool then return ending(s, 'end.nothing', 'inform') end
        return switch(s, snap.stage, tool)
    end
    local list = Session.toolList(s)
    if not usable(list, s.tool) then
        local tool = firstTool(s, s.stage)
        if not tool then return ending(s, s.stage == 'lock' and 'end.locked' or 'end.nothing', 'inform') end
        return switch(s, s.stage, tool)
    end
    Nui.send({ type = 'tools', list = list, active = s.tool })
end

function Session.removed(id)
    local s = Rob.session
    if s and s.id == id then Session.finish('removed') end
end

local function key(s, name, down)
    if name == 'Escape' or name == 'Backspace' then
        if down then Session.finish('leave') end
        return
    end
    if name == 'Tab' then
        Nui.send({ type = 'notes', open = down })
        return
    end
    if not down then return end
    local index = math.tointeger(tonumber(name))
    local tool = index and Session.toolList(s)[index]
    if tool then Session.select(s, tool.id) end
end

function Session.input(data)
    local s = Rob.session
    if not s or s.closing or s.ending or not s.stage then return end
    if GetGameTimer() < (Camera.readyAt or 0) then return end
    local m = module(s)
    local kind = data.kind
    if kind == 'tool' and type(data.id) == 'string' then return Session.select(s, data.id) end
    if kind == 'key' and type(data.key) == 'string' and #data.key <= 12 then return key(s, data.key, data.down ~= false) end
    if kind == 'wheel' then
        if m and m.wheel then m.wheel(s, (tonumber(data.delta) or 0) > 0 and 1 or -1) end
        return
    end
    local button = math.tointeger(data.button) or 0
    local nx, ny = Pointer.pos()
    if kind == 'down' then
        if m and m.down then m.down(s, button, nx, ny) end
    elseif kind == 'up' then
        if m and m.up then m.up(s, button) end
    end
end

RegisterNetEvent('cortex-vendrobbery:client:kicked', function(id)
    local s = Rob.session
    if s and s.id == id then Session.finish('kicked') end
end)

AddEventHandler('onResourceStop', function(name)
    if name ~= Rob.resource then return end
    if Rob.session then
        pcall(Session.finish, 'stopped')
        pcall(ClearPedTasks, PlayerPedId())
    end
end)
