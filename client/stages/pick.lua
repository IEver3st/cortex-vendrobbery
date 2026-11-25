Pick = {}

local TRAVEL = 0.26
local PANEL_X, PANEL_Y, GAP = 0.5, 0.66, 0.036
local REACH_UP, REACH_DOWN = 0.30, 0.07
local RISE, FALL = 0.55, 0.22
local HEAVY, LIGHT = CxVendRob.PickLift, 2.6
local OVERSHOOT = 0.05

local function onDoor(s) return s.stage == 'lock' end
local function pinCount(s) return onDoor(s) and CxVendRob.PinCount or CxVendRob.BoxPins end
local function setList(s) return onDoor(s) and s.rec.snap.pins or s.rec.snap.boxPins end
local function goalOf(s, pin) return s.lock.depths[pin] / (CxVendRob.Depths + 1) end

local function binding(s)
    local n, set = pinCount(s), setList(s)
    local done, seen = 0, 0
    for i = 1, n do
        if set[i] then done = done + 1 end
    end
    for _, pin in ipairs(s.lock.order) do
        if pin <= n then
            seen = seen + 1
            if seen == done + 1 then return pin end
        end
    end
    return nil
end

local function pinX(s, i)
    return PANEL_X + (i - (pinCount(s) + 1) / 2) * GAP
end

local function hoverPin(s, nx, ny)
    if ny < PANEL_Y - REACH_UP or ny > PANEL_Y + REACH_DOWN then return nil end
    local set = setList(s)
    for i = 1, pinCount(s) do
        if not set[i] and math.abs(nx - pinX(s, i)) <= GAP * 0.5 then return i end
    end
    return nil
end

function Pick.view(s) return onDoor(s) and 'lock' or 'box' end

function Pick.enter(s)
    s.pick = { torque = 0.0, rmb = false, drag = nil }
end

function Pick.exit(s)
    s.pick = nil
    Nui.send({ type = 'gauge', gauge = false })
    Nui.send({ type = 'hover', label = false })
    Tools.drop('hand')
end

local function strike(s, why)
    local p = s.pick
    p.drag, p.rmb, p.torque = nil, false, 0.12
    p.quietUntil = GetGameTimer() + 600
    Fx.sound(why == 'overset' and 'overset' or 'clang')
    Camera.shake('SMALL_EXPLOSION_SHAKE', 0.05)
    local door = onDoor(s)
    local code = why == 'overset' and (door and 'overset' or 'boxset') or (door and 'torque' or 'boxtorque')
    CreateThread(function() Rob.await('strike', s.id, code) end)
    Rob.notify('error', L(why == 'overset' and 'pick.overset' or 'pick.torque'))
end

local function setPin(s, pin)
    local p = s.pick
    p.drag = nil
    p.pending = pin
    local door = onDoor(s)
    CreateThread(function()
        local ok = Rob.await(door and 'pin' or 'boxpin', s.id, pin)
        if Rob.session ~= s then return end
        if s.pick then s.pick.pending = nil end
        if ok then
            s.rec.notes[pin] = s.lock.depths[pin]
            Fx.sound('set')
            Session.notebook(s)
        else
            Rob.notify('inform', L('pick.slipped'))
        end
    end)
end

function Pick.frame(s, nx, ny)
    local p = s.pick
    if not p then return end
    local dt = GetFrameTime()
    local now = GetGameTimer()
    local band = Config.Pick.torque
    if p.rmb then
        p.torque = math.min(1.0, p.torque + RISE * dt)
    else
        p.torque = math.max(0.0, p.torque - FALL * dt)
    end
    if p.torque >= Config.Pick.breakAt then return strike(s, 'torque') end
    local inBand = p.torque >= band[1] and p.torque <= band[2]
    local want = binding(s)
    local d = p.drag
    if d then
        local raw = Geo.clamp((d.startY - ny) / TRAVEL, 0.0, 1.0)
        local heavy = inBand and d.pin == want
        d.lift = Geo.clamp(d.lift + Geo.clamp(raw - d.lift, -4.0 * dt, (d.pin == want and HEAVY or LIGHT) * dt), 0.0, 1.0)
        if heavy then
            local goal = goalOf(s, d.pin)
            if d.lift > goal + Config.Pick.window + OVERSHOOT then return strike(s, 'overset') end
            if math.abs(d.lift - goal) <= Config.Pick.window then
                if not d.inAt then
                    d.inAt = now
                    Fx.sound('bind')
                end
                if now - d.inAt >= Config.Pick.bindMs then setPin(s, d.pin) end
            else
                d.inAt = nil
            end
        else
            d.inAt = nil
        end
    end
    d = p.drag
    local hover = not d and hoverPin(s, nx, ny) or nil
    if hover ~= s.hover then
        s.hover = hover
        if hover then Fx.sound('tick') end
    end
    local set = setList(s)
    local known = s.rec.snap.route == 'pick'
    local pins = {}
    for i = 1, pinCount(s) do
        local lifted = d and d.pin == i
        pins[i] = {
            x = pinX(s, i),
            lift = set[i] and goalOf(s, i) or (lifted and d.lift or 0.0),
            set = set[i] or p.pending == i or false,
            bite = lifted and d.inAt ~= nil or false,
            heavy = lifted and inBand and i == want or false,
            hot = hover == i or lifted or false,
            mark = (not set[i] and (s.rec.notes[i] or (known and not onDoor(s)))) and goalOf(s, i) or false,
        }
    end
    Nui.send({ type = 'gauge', gauge = { kind = 'pick', x = PANEL_X, y = PANEL_Y, torque = p.torque, low = band[1], high = band[2],
        brk = Config.Pick.breakAt, window = Config.Pick.window, pins = pins } })
    Nui.send({ type = 'hover', label = false })
    Nui.send({ type = 'targets', list = {} })
end

function Pick.down(s, button, nx, ny)
    local p = s.pick
    if not p or (p.quietUntil and GetGameTimer() < p.quietUntil) then return end
    if button == 2 then
        p.rmb = true
        Fx.sound('grip')
        return
    end
    if button ~= 0 or p.drag or p.pending then return end
    local pin = hoverPin(s, nx, ny)
    if not pin then return end
    p.drag = { pin = pin, startY = ny, lift = 0.0 }
    Fx.sound('bite')
end

function Pick.up(s, button)
    local p = s.pick
    if not p then return end
    if button == 2 then p.rmb = false end
    if button == 0 then p.drag = nil end
end

function Pick.wheel(s, delta)
    local p = s.pick
    if p then p.torque = Geo.clamp(p.torque - delta * 0.035, 0.0, 1.0) end
end

function Pick.help()
    return {
        { label = L('help.lift'), value = 'LMB' },
        { label = L('help.tension'), value = 'RMB' },
        { label = L('help.notes'), value = 'TAB' },
        { label = L('help.tools'), value = '1-4' },
        { label = L('help.leave'), value = 'ESC' },
    }
end
