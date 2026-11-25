Robbery = Robbery or {}

local machines = {}
local working = {}
local cooldownUntil = {}
local retryUntil = {}
local lockSpent = {}
local sweeping = false

Robbery.machines = machines
Robbery.working = working

local IDLE_SECONDS = 180
local UNTOUCHED_SECONDS = 60
local LOCK_SECONDS = 300
local LOCK_FORGIVE = 900
local NEXT = 'next:%d'
local GONE = { not_found = true, refused = true, held = true }

local function falses(n)
    local out = {}
    for i = 1, n do out[i] = false end
    return out
end

local function shuffled(n)
    local out = {}
    for i = 1, n do out[i] = i end
    for i = n, 2, -1 do
        local j = math.random(1, i)
        out[i], out[j] = out[j], out[i]
    end
    return out
end

local function count(list)
    local n = 0
    for i = 1, #list do
        if list[i] then n = n + 1 end
    end
    return n
end
Robbery.count = count

function Robbery.snapshot(machine)
    return {
        id = machine.id,
        type = machine.type,
        coords = { x = machine.at.x, y = machine.at.y, z = machine.at.z },
        heading = machine.heading,
        stage = machine.stage,
        route = machine.route or false,
        pins = machine.pins,
        pry = machine.pry,
        jammed = machine.jammed,
        strikes = machine.strikes,
        stacker = machine.stacker,
        box = machine.box,
        boxPins = machine.boxPins,
        drill = machine.drill,
        seized = machine.seized,
        drawer = machine.drawer,
        shelfLeft = machine.shelvesEmpty and 0 or math.max(0, Config.Takings.shelfItems - machine.items),
        worker = machine.worker or false,
        owner = machine.owner or false,
        alarmLeft = math.max(0, (machine.alarmEnds or 0) - os.time()),
        paid = machine.paid,
    }
end

function Robbery.secret(machine)
    return { depths = machine.depths, order = machine.order }
end

local function inBucket(machine, fn)
    for _, player in ipairs(GetPlayers()) do
        local src = tonumber(player)
        if src and GetPlayerRoutingBucket(src) == machine.bucket then fn(src) end
    end
end

function Robbery.broadcast(machine, removed)
    if removed then
        TriggerClientEvent('cortex-vendrobbery:client:machine', -1, machine.id, nil)
        return
    end
    if machines[machine.id] ~= machine then return end
    local payload = Robbery.snapshot(machine)
    inBucket(machine, function(src)
        TriggerClientEvent('cortex-vendrobbery:client:machine', src, machine.id, payload)
    end)
end

function Robbery.effect(machine, kind, data)
    inBucket(machine, function(src)
        local ped = GetPlayerPed(src)
        if ped ~= 0 and #(GetEntityCoords(ped) - machine.at) < 120.0 then
            TriggerClientEvent('cortex-vendrobbery:client:effect', src, machine.id, kind, data)
        end
    end)
end

function Robbery.sendAll(source)
    local bucket = GetPlayerRoutingBucket(source)
    local list = {}
    for _, machine in pairs(machines) do
        if machine.bucket == bucket then list[#list + 1] = Robbery.snapshot(machine) end
    end
    TriggerClientEvent('cortex-vendrobbery:client:all', source, list)
end

function Robbery.stampCooldown(source, identity)
    if Config.Cooldown.playerMinutes > 0 then
        cooldownUntil[identity or Robbery.identity(source)] = os.time() + math.floor(Config.Cooldown.playerMinutes * 60)
    end
end

function Robbery.cooldownLeft(source)
    local identity = Robbery.identity(source)
    local untilAt = math.max(cooldownUntil[identity] or 0, retryUntil[identity] or 0)
    return math.max(0, untilAt - os.time())
end

function Robbery.clearCooldown(source)
    local identity = Robbery.identity(source)
    cooldownUntil[identity], retryUntil[identity] = nil, nil
    for key in pairs(lockSpent) do
        if key:sub(1, #identity + 1) == identity .. ':' then lockSpent[key] = nil end
    end
end

Robbery.lockSeconds = LOCK_SECONDS

function Robbery.lockUsed(source, id)
    local key = Robbery.identity(source) .. ':' .. id
    local spent = lockSpent[key]
    if not spent then return 0, 0 end
    local since = os.time() - spent.at
    if since >= LOCK_FORGIVE then
        lockSpent[key] = nil
        return 0, 0
    end
    return spent.used, LOCK_FORGIVE - since
end

local function chargeLock(source, machine)
    local now = os.time()
    for key, spent in pairs(lockSpent) do
        if now - spent.at >= LOCK_FORGIVE then lockSpent[key] = nil end
    end
    lockSpent[Robbery.identity(source) .. ':' .. machine.id] = { used = math.max(0, now - (machine.lockSince or now)), at = now }
end

function Robbery.machineCooldown(id)
    return math.max(0, GetResourceKvpInt(NEXT:format(id)) - os.time())
end

function Robbery.clearMachineCooldown(id)
    DeleteResourceKvp(NEXT:format(id))
    local tail = ':' .. id
    for key in pairs(lockSpent) do
        if key:sub(-#tail) == tail then lockSpent[key] = nil end
    end
end

local function doorOf(machine)
    if machine.stage ~= 'lock' then return 1.0 end
    return count(machine.pry) * 0.04
end

function Robbery.hold(machine, actor)
    return Vending.hold(machine.id, { door = doorOf(machine), sign = machine.stage ~= 'lock', actor = actor })
end

local function forget(machine)
    machines[machine.id] = nil
    if machine.worker then
        working[machine.worker] = nil
        TriggerClientEvent('cortex-vendrobbery:client:kicked', machine.worker, machine.id)
        machine.worker = nil
    end
    Vending.hold(machine.id, nil)
    Robbery.broadcast(machine, true)
end

function Robbery.remove(machine)
    forget(machine)
end

function Robbery.stale(machine, now)
    local worker = machine.worker
    local ped = GetPlayerPed(worker)
    if not ped or ped == 0 then return true end
    if GetPlayerRoutingBucket(worker) ~= machine.bucket then return true end
    if #(GetEntityCoords(ped) - machine.at) > CxVendRob.Reach + 1.5 then return true end
    if machine.stage == 'lock' and now - (machine.lockSince or now) > LOCK_SECONDS then return true, 'cap' end
    local idle = now - (machine.lastAct or now)
    if idle > IDLE_SECONDS then return true end
    return idle > UNTOUCHED_SECONDS and not Robbery.touched(machine)
end

local function repairDelay(machine)
    local minutes = Config.Cooldown.repairMinutes + (machine.route == 'pry' and Config.Cooldown.pryRepairMinutes or 0)
    return math.floor(minutes * 60)
end

local function sweepOne(machine, now)
    if machine.opening or machine.beginning then return end
    if machine.worker or machine.stage ~= 'lock' then
        local ok, why = Robbery.hold(machine)
        if machines[machine.id] ~= machine or machine.opening or machine.beginning then return end
        if not ok and GONE[why] then
            Robbery.audit(nil, 'machine gone', machine, tostring(why))
            forget(machine)
            return
        end
    end
    local stale, why = false, nil
    if machine.worker then stale, why = Robbery.stale(machine, now) end
    if stale then
        local worker = machine.worker
        if why == 'cap' then
            Robbery.stampCooldown(worker)
            local hold = os.time() + math.floor(Config.Cooldown.abandonMinutes * 60)
            SetResourceKvpInt(NEXT:format(machine.id), math.max(GetResourceKvpInt(NEXT:format(machine.id)), hold))
            Robbery.audit(worker, 'ran out of time on the lock', machine)
        end
        TriggerClientEvent('cortex-vendrobbery:client:kicked', worker, machine.id)
        Robbery.release(worker)
    end
    if machines[machine.id] ~= machine or machine.worker or machine.repairing then return end
    if not machine.repairAt and machine.idleSince and now - machine.idleSince >= Config.Cooldown.abandonMinutes * 60 then
        machine.repairAt = now + (machine.stage == 'lock' and 0 or repairDelay(machine))
    end
    if machine.repairAt and now >= machine.repairAt then
        Robbery.audit(nil, 'repaired', machine, ('$%d taken'):format(machine.paid))
        forget(machine)
    end
end

local function startSweep()
    if sweeping then return end
    sweeping = true
    CreateThread(function()
        while next(machines) do
            Wait(15000)
            local now = os.time()
            local list = {}
            for _, machine in pairs(machines) do list[#list + 1] = machine end
            for _, machine in ipairs(list) do
                if machines[machine.id] == machine then
                    local ok, err = pcall(sweepOne, machine, now)
                    if not ok then print(('^1[cortex-vendrobbery]^7 sweep of machine %d failed: %s'):format(machine.id, tostring(err))) end
                end
            end
        end
        sweeping = false
    end)
end

function Robbery.create(source, info)
    local depths = {}
    for i = 1, CxVendRob.PinCount do depths[i] = math.random(1, CxVendRob.Depths) end
    local machine = {
        id = info.id,
        type = info.type,
        bucket = info.bucket or 0,
        at = vector3(info.coords.x + 0.0, info.coords.y + 0.0, info.coords.z + 0.0),
        heading = (info.heading or 0.0) + 0.0,
        vendex = info.vendex == true,
        owner = info.owner or nil,
        label = info.label or nil,
        stage = 'lock',
        route = nil,
        depths = depths,
        order = shuffled(CxVendRob.PinCount),
        pins = falses(CxVendRob.PinCount),
        pry = falses(CxVendRob.PryPoints),
        jammed = false,
        strikes = 0,
        stacker = CxVendRob.has(info.type, 'stacker') and 0 or -1,
        box = 0,
        boxPins = falses(CxVendRob.BoxPins),
        drill = 0.0,
        seized = false,
        drawer = {},
        values = {},
        notes = 0,
        pool = 0,
        float = 0,
        paid = 0,
        items = 0,
        worker = nil,
        lastAct = os.time(),
        stageAt = GetGameTimer(),
        pinAt = 0,
        openedBy = Robbery.identity(source),
    }
    machines[machine.id] = machine
    startSweep()
    return machine
end

local function emptiness(info)
    local stock, capacity = 0, 0
    for _, row in ipairs(info.slots or {}) do
        stock = stock + (tonumber(row.stock) or 0)
        capacity = capacity + (tonumber(row.capacity) or 0)
    end
    if capacity <= 0 then return 0.0 end
    return math.min(1.0, math.max(0.0, 1.0 - stock / capacity))
end

function Robbery.fillTakings(source, machine)
    local info = Vending.info(machine.id, Robbery.citizenid(source)) or {}
    local cash = math.max(0, math.floor(tonumber(info.cash) or 0))
    local t = Config.Takings
    if machine.vendex then
        machine.pool = math.min(t.vendexMax, math.floor(cash * t.vendexShare))
        machine.float = math.floor(t.vendexFloat[1] + (t.vendexFloat[2] - t.vendexFloat[1]) * emptiness(info))
    else
        machine.pool = math.min(t.playerMax, math.floor(cash * t.playerShare))
        machine.float = 0
    end
    local stock = 0
    for _, row in ipairs(info.slots or {}) do
        if row.item then stock = stock + (tonumber(row.stock) or 0) end
    end
    machine.shelvesEmpty = stock == 0
    local total = machine.pool + machine.float
    machine.notes = machine.stacker >= 0 and math.floor(total * t.stackerShare) or 0
    local box = total - machine.notes
    local filled = box > 0 and math.min(t.drawerSlots, math.max(1, box // 40)) or 0
    local each = filled > 0 and box // filled or 0
    machine.drawer, machine.values = {}, {}
    for i = 1, t.drawerSlots do
        machine.drawer[i] = i <= filled
        machine.values[i] = i <= filled and (i == filled and box - each * (filled - 1) or each) or 0
    end
    if machine.stacker >= 0 and machine.notes <= 0 then machine.stacker = 2 end
    return total
end

function Robbery.tripAlarm(source, machine)
    if machine.alarmEnds and machine.alarmEnds > os.time() then return end
    machine.alarmEnds = os.time() + math.floor(Config.Alarm.seconds)
    Robbery.alert(source, machine, 'alarm')
    Robbery.effect(machine, 'alarm', { seconds = Config.Alarm.seconds })
    Robbery.tellOwner(machine, 'owner.alarm', machine.label or L(CxVendRob.Machines[machine.type].label))
end

function Robbery.openDoor(source, machine, route)
    local opener = Robbery.identity(source)
    machine.opening = true
    local held, why = Vending.hold(machine.id, { door = 1.0, sign = true, actor = Robbery.citizenid(source) })
    if machines[machine.id] ~= machine then
        machine.opening = nil
        return false
    end
    if not held then
        machine.opening = nil
        Robbery.audit(source, 'door hold refused', machine, tostring(why))
        forget(machine)
        return false
    end
    local total = Robbery.fillTakings(source, machine)
    machine.opening = nil
    if machines[machine.id] ~= machine then return false end
    machine.stage = 'open'
    machine.route = route
    machine.openedBy = opener
    machine.stageAt = GetGameTimer()
    machine.pinAt = machine.stageAt
    machine.strikes = 0
    if Config.Cooldown.machineMinutes > 0 then
        SetResourceKvpInt(NEXT:format(machine.id), os.time() + math.floor(Config.Cooldown.machineMinutes * 60))
    end
    Robbery.stampCooldown(source, opener)
    if route == 'pry' then
        Robbery.tripAlarm(source, machine)
    elseif math.random() < Config.Police.witnessChance then
        Robbery.alert(source, machine, 'witness')
    end
    Robbery.audit(source, route == 'pry' and 'door levered open' or 'lock picked', machine, ('$%d inside'):format(total))
    return true
end

function Robbery.strike(source, machine, why)
    machine.strikes = machine.strikes + 1
    if why == 'overset' then
        local dropped = 0
        for i = CxVendRob.PinCount, 1, -1 do
            local pin = machine.order[i]
            if machine.pins[pin] and dropped < 2 then
                machine.pins[pin] = false
                dropped = dropped + 1
            end
        end
    elseif why == 'boxset' then
        machine.boxPins = falses(CxVendRob.BoxPins)
    end
    if machine.strikes < Config.Strikes then return false end
    machine.strikes = 0
    if machine.stage == 'lock' and (why == 'overset' or why == 'torque') then
        machine.jammed = true
        machine.pins = falses(CxVendRob.PinCount)
    elseif machine.stage == 'open' and (why == 'boxset' or why == 'boxtorque' or why == 'snap') then
        machine.seized = true
    end
    Robbery.tripAlarm(source, machine)
    Robbery.audit(source, 'struck out', machine, why)
    return true
end

function Robbery.cashLeft(machine)
    if machine.stage == 'lock' then return true end
    if machine.stacker == 0 then return true end
    if machine.seized or machine.box == 2 then return false end
    return true
end

function Robbery.spent(machine)
    if machine.stage ~= 'open' or Robbery.cashLeft(machine) then return false end
    if CxVendRob.has(machine.type, 'shelves') and machine.items < Config.Takings.shelfItems and not machine.shelvesEmpty then return false end
    return true
end

function Robbery.finish(source, machine)
    machine.stage = 'spent'
    machine.repairAt = os.time() + repairDelay(machine)
    Robbery.audit(source, 'cleaned out', machine, ('$%d and %d items'):format(machine.paid, machine.items))
    Robbery.tellOwner(machine, 'owner.robbed', machine.label or L(CxVendRob.Machines[machine.type].label))
end

function Robbery.touched(machine)
    return machine.stage ~= 'lock' or machine.strikes > 0 or machine.jammed or count(machine.pins) > 0 or count(machine.pry) > 0
end

function Robbery.release(source)
    local id = working[source]
    if not id then return end
    working[source] = nil
    local machine = machines[id]
    if not machine or machine.worker ~= source then return end
    machine.worker = nil
    machine.idleSince = os.time()
    if machine.opening or machine.beginning then
        if machine.opening then Robbery.broadcast(machine) end
        return
    end
    if machine.stage == 'lock' then
        chargeLock(source, machine)
        if Config.Cooldown.retrySeconds > 0 then
            retryUntil[Robbery.identity(source)] = os.time() + math.floor(Config.Cooldown.retrySeconds)
        end
    end
    if not Robbery.touched(machine) then
        forget(machine)
        return
    end
    if machine.stage == 'lock' then
        machine.pins = falses(CxVendRob.PinCount)
        Vending.hold(machine.id, nil)
    end
    Robbery.broadcast(machine)
end

AddEventHandler('playerDropped', function()
    Robbery.release(source)
end)

AddEventHandler('qbx_core:server:playerLoggedOut', function(src)
    src = tonumber(src) or source
    if not src or not working[src] then return end
    TriggerClientEvent('cortex-vendrobbery:client:kicked', src, working[src])
    Robbery.release(src)
end)

local function dropLocal(machine)
    machines[machine.id] = nil
    if machine.worker then
        working[machine.worker] = nil
        TriggerClientEvent('cortex-vendrobbery:client:kicked', machine.worker, machine.id)
        machine.worker = nil
    end
    Robbery.broadcast(machine, true)
end

AddEventHandler('cortex-vending:tamper:revoked', function(id, why, by)
    if by ~= GetCurrentResourceName() then return end
    local machine = machines[tonumber(id) or -1]
    if not machine then return end
    Robbery.audit(nil, 'hold revoked', machine, tostring(why))
    dropLocal(machine)
end)

AddEventHandler('onResourceStop', function(name)
    if name ~= 'cortex-vending' then return end
    local list = {}
    for _, machine in pairs(machines) do list[#list + 1] = machine end
    for _, machine in ipairs(list) do dropLocal(machine) end
end)
