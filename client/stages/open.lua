Open = {}

local HOVER_PX = 60
local PULL_TRAVEL = 0.22
local SHELF_MS = 380
local VIEWS = { stacker = 'door', drill = 'box', drawer = 'box', shelves = 'shelves' }

function Open.view(s) return VIEWS[s.tool] or 'open' end

local function clear(s)
    s.pull, s.drilling, s.grabbing = nil, nil, nil
    Nui.send({ type = 'gauge', gauge = false })
end

function Open.enter(s)
    clear(s)
    s.heat = s.heat or 0.0
    s.credit = 0.0
end

function Open.exit(s)
    clear(s)
    Nui.send({ type = 'targets', list = {} })
    Nui.send({ type = 'hover', label = false })
    Tools.drop('hand')
end

local function carry(result)
    if type(result) == 'table' and result.error == 'carry' then Rob.notify('error', L('loot.carry')) end
end

local function cash(s, result, at)
    if type(result) ~= 'table' or not result.ok then return carry(result) end
    Fx.sound('grab', at)
    Nui.send({ type = 'cash', amount = result.amount or 0, total = result.total or result.amount or 0, dyed = false })
end

local function stackerPoint(s)
    local st = s.rec.def.stacker
    return st and World.doorPoint(s.rec, st.at.x, st.at.y, st.at.z) or nil
end

local function frameStacker(s, nx, ny)
    local at = stackerPoint(s)
    local taken = s.rec.snap.stacker ~= 0
    local list = { { at = at, skip = taken or not at } }
    local sp = at and Pointer.screen(at)
    local pull = s.pull
    if pull then
        pull.value = Geo.clamp((ny - pull.startY) / PULL_TRAVEL, 0.0, 1.0)
        Nui.send({ type = 'gauge', gauge = { kind = 'pull', x = sp and sp.x or nx, y = sp and sp.y or ny, value = pull.value } })
        if pull.value >= 1.0 and not pull.sent then
            pull.sent = true
            CreateThread(function()
                local result = Rob.await('stacker', s.id)
                if Rob.session ~= s then return end
                s.pull = nil
                Nui.send({ type = 'gauge', gauge = false })
                cash(s, result, at)
            end)
        end
    else
        local hover = Pointer.nearest(nx, ny, list, HOVER_PX)
        if hover ~= s.hover then
            s.hover = hover
            if hover then Fx.sound('tick') end
        end
        Nui.send({ type = 'hover', label = hover and L('hud.stacker') or false })
    end
    Nui.send({ type = 'targets', list = (sp and not taken) and { { x = sp.x, y = sp.y, kind = 'handle', hot = s.hover == 1 or pull ~= nil } } or {} })
end

local function strikeSnap(s, at)
    s.drilling = nil
    s.heat = 0.35
    Fx.sound('snap', at)
    Fx.sparks(at, 0.3)
    Camera.shake('SMALL_EXPLOSION_SHAKE', 0.07)
    CreateThread(function() Rob.await('strike', s.id, 'snap') end)
    Rob.notify('error', L('drill.snap'))
end

local function frameDrill(s, nx, ny)
    local snap = s.rec.snap
    local at = World.at(s.rec, s.rec.def.box.lock)
    local sp = Pointer.screen(at)
    local dt = GetFrameTime()
    local c = Config.Drill
    if s.drilling then
        s.heat = math.min(1.0, s.heat + c.heatPerSecond * dt)
        if s.heat >= c.snapAt then return strikeSnap(s, at) end
        local inZone = s.heat >= c.zone[1] and s.heat <= c.zone[2]
        s.credit = s.credit + dt * (inZone and 1.0 or 0.3)
        if math.random() < dt * 9.0 then Fx.sparks(at, inZone and 0.12 or 0.07) end
        if s.credit >= 1.0 and not s.reporting then
            s.credit = s.credit - 1.0
            s.reporting = true
            CreateThread(function()
                Rob.await('drill', s.id)
                s.reporting = false
            end)
        end
    else
        s.heat = math.max(0.0, s.heat - c.coolPerSecond * dt)
    end
    local hover = Pointer.nearest(nx, ny, { { at = at } }, HOVER_PX)
    if hover ~= s.hover then
        s.hover = hover
        if hover then Fx.sound('tick') end
    end
    Nui.send({ type = 'hover', label = (hover and not s.drilling) and L('hud.boxlock') or false })
    Nui.send({ type = 'targets', list = sp and { { x = sp.x, y = sp.y, kind = 'screw', hot = hover == 1 or s.drilling ~= nil } } or {} })
    if s.drilling or s.heat > 0.02 then
        Nui.send({ type = 'gauge', gauge = { kind = 'lever', x = sp and sp.x or nx, y = sp and sp.y or ny, value = s.heat, low = c.zone[1], high = c.zone[2],
            slip = c.snapAt, hold = Geo.clamp((snap.drill or 0.0) + s.credit / c.seconds, 0.0, 1.0) } })
    else
        Nui.send({ type = 'gauge', gauge = false })
    end
end

local function bundlePoints(s)
    local box = s.rec.def.box
    local drawer = s.rec.snap.drawer or {}
    local n = #drawer
    local out = {}
    for i = 1, n do
        local col, row = (i - 1) % 4, (i - 1) // 4
        local x = box.at.x + (col - 1.5) * 0.03
        local z = box.at.z + 0.02 - row * 0.04
        out[i] = { at = World.point(s.rec, x, box.at.y - box.size.y * 0.5 - 0.012, z), skip = not drawer[i] }
    end
    return out
end

local function frameDrawer(s, nx, ny)
    local list = bundlePoints(s)
    local hover = Pointer.nearest(nx, ny, list, 40)
    if hover ~= s.hover then
        s.hover = hover
        if hover then Fx.sound('tick') end
    end
    local targets = {}
    for i, p in ipairs(list) do
        if not p.skip then
            local sp = Pointer.screen(p.at)
            if sp then targets[#targets + 1] = { x = sp.x, y = sp.y, kind = 'bundle', hot = hover == i } end
        end
    end
    Nui.send({ type = 'hover', label = hover and L('hud.bundle') or false })
    Nui.send({ type = 'targets', list = targets })
end

local function shelfPoints(s)
    local out = {}
    for i, row in ipairs(World.products(s.rec)) do
        local exists = row.entity and DoesEntityExist(row.entity)
        out[i] = { at = exists and GetEntityCoords(row.entity) or nil, skip = not exists, slot = row.slot }
    end
    return out
end

local function takeShelf(s, slot, at)
    if s.shelfBusy then return end
    s.shelfBusy = true
    s.shelfAt = GetGameTimer()
    CreateThread(function()
        local result = Rob.await('shelf', s.id, slot)
        s.shelfBusy = false
        if Rob.session ~= s then return end
        s.rec.productsAt = 0
        if type(result) == 'table' and result.ok then
            Fx.sound('grab', at)
            Nui.send({ type = 'hint', text = L('loot.item', result.label or '', result.left or 0) })
        elseif type(result) == 'table' and result.error == 'cap' then
            s.grabbing = nil
            Rob.notify('inform', L('loot.cap'))
        else
            carry(result)
        end
    end)
end

local function frameShelves(s, nx, ny)
    local list = shelfPoints(s)
    local hover = Pointer.nearest(nx, ny, list, 44)
    if hover ~= s.hover then
        s.hover = hover
        if hover then Fx.sound('tick') end
    end
    local targets = {}
    for i, p in ipairs(list) do
        if not p.skip then
            local sp = Pointer.screen(p.at)
            if sp then targets[#targets + 1] = { x = sp.x, y = sp.y, kind = 'bundle', hot = hover == i } end
        end
    end
    Nui.send({ type = 'hover', label = hover and L('hud.product') or false, status = L('hud.left', s.rec.snap.shelfLeft or 0) })
    Nui.send({ type = 'targets', list = targets })
    if s.grabbing and hover and GetGameTimer() - (s.shelfAt or 0) >= SHELF_MS then takeShelf(s, list[hover].slot, list[hover].at) end
end

local FRAMES = { stacker = frameStacker, drill = frameDrill, drawer = frameDrawer, shelves = frameShelves }

function Open.frame(s, nx, ny)
    local fn = FRAMES[s.tool]
    if fn then return fn(s, nx, ny) end
    Nui.send({ type = 'targets', list = {} })
    Nui.send({ type = 'hover', label = false })
end

function Open.down(s, button, nx, ny)
    if button ~= 0 then return end
    if s.tool == 'stacker' then
        if s.pull or s.rec.snap.stacker ~= 0 then return end
        local at = stackerPoint(s)
        if at and Pointer.nearest(nx, ny, { { at = at } }, HOVER_PX) then
            s.pull = { startY = ny, value = 0.0 }
            Fx.sound('grip', at)
        end
    elseif s.tool == 'drill' then
        local at = World.at(s.rec, s.rec.def.box.lock)
        if Pointer.nearest(nx, ny, { { at = at } }, HOVER_PX) then
            s.drilling = true
            Fx.sound('drill', at)
        end
    elseif s.tool == 'drawer' then
        local list = bundlePoints(s)
        local hover = Pointer.nearest(nx, ny, list, 40)
        if not hover or s.grabBusy then return end
        s.grabBusy = true
        CreateThread(function()
            local result = Rob.await('grab', s.id, hover)
            s.grabBusy = false
            if Rob.session == s then cash(s, result, list[hover].at) end
        end)
    elseif s.tool == 'shelves' then
        s.grabbing = true
        local list = shelfPoints(s)
        local hover = Pointer.nearest(nx, ny, list, 44)
        if hover then takeShelf(s, list[hover].slot, list[hover].at) end
    end
end

function Open.up(s, button)
    if button ~= 0 then return end
    if s.pull and not s.pull.sent then
        s.pull = nil
        Nui.send({ type = 'gauge', gauge = false })
    end
    s.drilling = nil
    s.grabbing = nil
end

local VERB = { stacker = 'help.pull', drill = 'help.drill', drawer = 'help.take', shelves = 'help.take' }

function Open.help(s)
    local out = {}
    if VERB[s.tool] then out[#out + 1] = { label = L(VERB[s.tool]), value = 'LMB' } end
    out[#out + 1] = { label = L('help.tools'), value = '1-4' }
    out[#out + 1] = { label = L('help.leave'), value = 'ESC' }
    return out
end
