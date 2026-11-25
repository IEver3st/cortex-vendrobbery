local machines, working = Robbery.machines, Robbery.working
local RESOURCE = GetCurrentResourceName()

local RATE = { begin = 1500, pin = 250, pry = 450, strike = 400, stacker = 800, boxpin = 150, drill = 850, grab = 400, shelf = 320, repair = 2000, sync = 4000 }
local PRY_MIN_MS = math.floor(Config.Pry.holdMs * CxVendRob.PryPoints * 0.6)
local WHY = { slip = 'lock', overset = 'lock', torque = 'lock', boxset = 'open', boxtorque = 'open', snap = 'open' }
local HOLD_ERRORS = { tray = 'tray', busy = 'inuse', held = 'taken' }
local lastAction = {}
local holding = {}

local function whole(value, low, high)
    local n = math.tointeger(value)
    if not n or n < low or n > high then return nil end
    return n
end

local function fit(source)
    local ped = GetPlayerPed(source)
    if ped == 0 or GetEntityHealth(ped) <= 0 then return nil end
    if GetVehiclePedIsIn(ped, false) ~= 0 then return nil end
    if Robbery.restrained(source) then return nil end
    return ped
end

local function limited(source, action)
    local now = GetGameTimer()
    lastAction[source] = lastAction[source] or {}
    local last = lastAction[source][action]
    if last and now - last < RATE[action] then return true end
    lastAction[source][action] = now
    return false
end

local function session(source, id, action)
    id = math.tointeger(id)
    local machine = id and machines[id]
    if not machine or machine.worker ~= source or working[source] ~= id or machine.opening or machine.beginning then return nil end
    local ped = fit(source)
    if not ped then return nil end
    if GetPlayerRoutingBucket(source) ~= machine.bucket then return nil end
    if #(GetEntityCoords(ped) - machine.at) > CxVendRob.Reach then return nil end
    if limited(source, action) then return nil end
    return machine
end

local function acted(machine)
    machine.lastAct = os.time()
end

local function pinFloor(machine, pin)
    local goal = machine.depths[pin] / (CxVendRob.Depths + 1)
    local lift = math.max(0.0, goal - Config.Pick.window) / CxVendRob.PickLift
    return math.max(350, math.floor(lift * 1000 + Config.Pick.bindMs) - 120)
end

local function workable(machine, have)
    if machine.stacker == 0 or machine.box == 1 then return true end
    if machine.box == 0 and not machine.seized and (have.pick or have.drill) then return true end
    return CxVendRob.has(machine.type, 'shelves') and not machine.shelvesEmpty and machine.items < Config.Takings.shelfItems
end

local function tools(source)
    return { pick = Robbery.hasTool(source, 'pick'), crowbar = Robbery.hasTool(source, 'crowbar'), drill = Robbery.hasTool(source, 'drill') }
end

local function fail(code, extra)
    local out = extra or {}
    out.ok, out.error = false, code
    return out
end

local function targetGate(info, cid)
    if info.vendex then
        if not Config.Targets.vendex then return fail('off') end
        return nil
    end
    if not Config.Targets.player then return fail('off') end
    if info.owner == cid then return fail('own') end
    return nil
end

local function heatGate(source)
    local left = Robbery.cooldownLeft(source)
    if left > 0 then return fail('cooldown', { minutes = math.ceil(left / 60) }) end
    if Config.Police.required > 0 and Robbery.policeOnDuty() < Config.Police.required then
        return fail('police', { needed = Config.Police.required })
    end
    return nil
end

local function freshGate(source, info, cid)
    local refused = targetGate(info, cid)
    if refused then return refused end
    if not info.vendex and Config.Targets.ownerOnline and not Robbery.sourceOf(info.owner) then return fail('away') end
    refused = heatGate(source)
    if refused then return refused end
    local recent = Robbery.machineCooldown(info.id)
    if recent > 0 then return fail('recent', { minutes = math.ceil(recent / 60) }) end
    local used, wait = Robbery.lockUsed(source, info.id)
    if used >= Robbery.lockSeconds then return fail('cooldown', { minutes = math.ceil(wait / 60) }) end
    return nil
end

lib.callback.register('cortex-vendrobbery:begin', function(source, id)
    id = whole(id, 1, 2147483647)
    if not id then return fail('invalid') end
    if limited(source, 'begin') then return fail('busy') end
    if not Vending.ready() then return fail('offline') end
    local ped = fit(source)
    local cid = Robbery.citizenid(source)
    if not ped or not cid then return fail('unfit') end
    if working[source] then return fail('busy') end
    local info = Vending.info(id, cid)
    if not info or not CxVendRob.Machines[info.type] then return fail('invalid') end
    local at = vector3(info.coords.x + 0.0, info.coords.y + 0.0, info.coords.z + 0.0)
    if #(GetEntityCoords(ped) - at) > CxVendRob.Reach + 0.5 then return fail('far') end
    if GetPlayerRoutingBucket(source) ~= (info.bucket or 0) then return fail('invalid') end

    local function current()
        local found = machines[id]
        if working[source] then return nil, fail('busy') end
        if holding[id] or (found and found.opening) then return nil, fail('taken') end
        if found then
            if found.stage == 'spent' then return nil, fail('spent') end
            if found.repairing or (found.worker and found.worker ~= source) then return nil, fail('taken') end
        elseif info.held and info.held ~= RESOURCE then
            return nil, fail('taken')
        end
        return found
    end

    local machine, refused = current()
    if refused then return refused end
    local takeover = machine ~= nil and machine.stage ~= 'lock' and machine.openedBy ~= Robbery.identity(source)
    if not machine or machine.stage == 'lock' then
        refused = freshGate(source, info, cid)
    else
        refused = targetGate(info, cid) or (takeover and heatGate(source)) or nil
    end
    if refused then return refused end

    local have = tools(source)
    local again
    again, refused = current()
    if refused then return refused end
    if again ~= machine then return fail('busy') end
    local stage = machine and machine.stage or 'lock'
    if stage == 'lock' and not have.crowbar and (not have.pick or (machine and machine.jammed)) then
        return fail('tool', { tool = Robbery.toolLabel(machine and machine.jammed and 'crowbar' or 'pick') })
    end
    if stage == 'open' and not workable(machine, have) then
        if machine.box == 0 and not machine.seized then return fail('tool', { tool = Robbery.toolLabel('drill') }) end
        return fail('spent')
    end

    local created = not machine
    if created then
        machine = Robbery.create(source, info)
    elseif stage == 'lock' then
        machine.vendex, machine.owner, machine.label = info.vendex == true, info.owner or nil, info.label or nil
        machine.at, machine.heading, machine.bucket = at, (info.heading or 0.0) + 0.0, info.bucket or 0
    end
    machine.worker = source
    working[source] = machine.id
    holding[id], machine.beginning = true, true
    local ran, held, why = pcall(Robbery.hold, machine, cid)
    holding[id], machine.beginning = nil, nil
    if not ran then held, why = false, 'error' end
    if not held or machines[id] ~= machine or machine.worker ~= source then
        if working[source] == id then working[source] = nil end
        if machine.worker == source then machine.worker = nil end
        if created and machines[id] == machine then machines[id] = nil end
        if held and (machines[id] == nil or (machines[id] == machine and machine.stage == 'lock' and not machine.worker)) then
            Vending.hold(id, nil)
        end
        return fail(HOLD_ERRORS[why] or 'invalid')
    end
    if created then Robbery.audit(source, 'started on', machine) end
    if takeover then
        machine.openedBy = Robbery.identity(source)
        Robbery.stampCooldown(source)
        Robbery.audit(source, 'took over', machine)
    end
    machine.idleSince = nil
    machine.lastAct = os.time()
    machine.pinAt = GetGameTimer()
    if stage == 'lock' then
        machine.repairAt = nil
        machine.stageAt = GetGameTimer()
        machine.lockSince = os.time() - math.min(Robbery.lockSeconds, (Robbery.lockUsed(source, id)))
        machine.pinFloor = 0
        machine.pryFrom = Robbery.count(machine.pry)
    end
    Robbery.broadcast(machine)
    return { ok = true, machine = Robbery.snapshot(machine), lock = Robbery.secret(machine), tools = have }
end)

lib.callback.register('cortex-vendrobbery:pin', function(source, id, pin)
    local machine = session(source, id, 'pin')
    pin = whole(pin, 1, CxVendRob.PinCount)
    if not machine or not pin or machine.stage ~= 'lock' or machine.jammed or machine.pins[pin] then return false end
    if not Robbery.hasTool(source, 'pick') then return false end
    local set = Robbery.count(machine.pins)
    if machine.order[set + 1] ~= pin then return false end
    local now = GetGameTimer()
    local floor = pinFloor(machine, pin)
    if now - machine.pinAt < floor or now - machine.stageAt < (machine.pinFloor or 0) + floor then return false end
    machine.pinAt = now
    machine.pinFloor = (machine.pinFloor or 0) + floor
    machine.pins[pin] = true
    acted(machine)
    Robbery.effect(machine, 'pin')
    if set + 1 == CxVendRob.PinCount and not Robbery.openDoor(source, machine, 'pick') then return false end
    Robbery.broadcast(machine)
    return true
end)

lib.callback.register('cortex-vendrobbery:pry', function(source, id, point)
    local machine = session(source, id, 'pry')
    point = whole(point, 1, CxVendRob.PryPoints)
    if not machine or not point or machine.stage ~= 'lock' or machine.pry[point] then return false end
    if not Robbery.hasTool(source, 'crowbar') then return false end
    local done = Robbery.count(machine.pry)
    if done == CxVendRob.PryPoints - 1 and GetGameTimer() - machine.stageAt < PRY_MIN_MS * (CxVendRob.PryPoints - (machine.pryFrom or 0)) // CxVendRob.PryPoints then return false end
    machine.pry[point] = true
    acted(machine)
    Robbery.effect(machine, 'pop')
    if done + 1 == CxVendRob.PryPoints then
        if not Robbery.openDoor(source, machine, 'pry') then return false end
    else
        Robbery.hold(machine)
        if done == 0 and math.random() < Config.Police.witnessChance then Robbery.alert(source, machine, 'witness') end
    end
    Robbery.broadcast(machine)
    return true
end)

local function settleSpent(source, machine)
    if Robbery.spent(machine) then Robbery.finish(source, machine) end
end

lib.callback.register('cortex-vendrobbery:strike', function(source, id, why)
    local machine = session(source, id, 'strike')
    if not machine or WHY[why] ~= machine.stage then return false end
    if machine.stage == 'lock' and machine.jammed and why ~= 'slip' then return false end
    if machine.stage == 'open' and (machine.box ~= 0 or machine.seized) then return false end
    local out = Robbery.strike(source, machine, why)
    settleSpent(source, machine)
    Robbery.effect(machine, out and 'lockout' or 'clang')
    Robbery.broadcast(machine)
    return true
end)

lib.callback.register('cortex-vendrobbery:stacker', function(source, id)
    local machine = session(source, id, 'stacker')
    if not machine or machine.stage ~= 'open' or machine.stacker ~= 0 then return { ok = false } end
    if GetGameTimer() - machine.stageAt < 800 then return { ok = false } end
    machine.stacker = 2
    local paid, amount, keep = Robbery.payCash(source, machine, machine.notes)
    if machines[machine.id] ~= machine then return { ok = paid == true, amount = paid and amount or nil } end
    if not paid and not keep then
        machine.stacker = 0
        return { ok = false, error = amount }
    end
    if paid then machine.paid = machine.paid + amount end
    acted(machine)
    settleSpent(source, machine)
    Robbery.effect(machine, 'grab')
    Robbery.broadcast(machine)
    return { ok = paid == true, amount = paid and amount or nil, total = machine.paid }
end)

local function boxOrder(machine)
    local out = {}
    for _, pin in ipairs(machine.order) do
        if pin <= CxVendRob.BoxPins then out[#out + 1] = pin end
    end
    return out
end

local function openBox(source, machine, how)
    machine.box = 1
    machine.strikes = 0
    local any = false
    for i = 1, #machine.drawer do any = any or machine.drawer[i] end
    if not any then machine.box = 2 end
    Robbery.audit(source, 'cash box opened', machine, how)
end

lib.callback.register('cortex-vendrobbery:boxpin', function(source, id, pin)
    local machine = session(source, id, 'boxpin')
    pin = whole(pin, 1, CxVendRob.BoxPins)
    if not machine or not pin or machine.stage ~= 'open' or machine.box ~= 0 or machine.seized or machine.boxPins[pin] then return false end
    if not Robbery.hasTool(source, 'pick') then return false end
    local set = Robbery.count(machine.boxPins)
    if boxOrder(machine)[set + 1] ~= pin then return false end
    local now = GetGameTimer()
    if now - machine.pinAt < pinFloor(machine, pin) then return false end
    machine.pinAt = now
    machine.boxPins[pin] = true
    acted(machine)
    Robbery.effect(machine, 'pin')
    if set + 1 == CxVendRob.BoxPins then
        openBox(source, machine, 'picked')
        settleSpent(source, machine)
    end
    Robbery.broadcast(machine)
    return true
end)

lib.callback.register('cortex-vendrobbery:drill', function(source, id)
    local machine = session(source, id, 'drill')
    if not machine or machine.stage ~= 'open' or machine.box ~= 0 or machine.seized then return false end
    if not Robbery.hasTool(source, 'drill') then return false end
    machine.drill = math.min(1.0, machine.drill + 1.0 / Config.Drill.seconds)
    acted(machine)
    Robbery.effect(machine, 'drill')
    if machine.drill >= 0.999 then
        openBox(source, machine, 'drilled')
        settleSpent(source, machine)
    end
    Robbery.broadcast(machine)
    return machine.drill
end)

lib.callback.register('cortex-vendrobbery:grab', function(source, id, slot)
    local machine = session(source, id, 'grab')
    slot = whole(slot, 1, Config.Takings.drawerSlots)
    if not machine or not slot or machine.stage ~= 'open' or machine.box ~= 1 or not machine.drawer[slot] then return { ok = false } end
    machine.drawer[slot] = false
    local paid, amount, keep = Robbery.payCash(source, machine, machine.values[slot])
    if machines[machine.id] ~= machine then return { ok = paid == true, amount = paid and amount or nil } end
    if not paid and not keep then
        machine.drawer[slot] = true
        return { ok = false, error = amount }
    end
    if paid then machine.paid = machine.paid + amount end
    acted(machine)
    if Robbery.count(machine.drawer) == 0 then machine.box = 2 end
    settleSpent(source, machine)
    Robbery.effect(machine, 'grab')
    Robbery.broadcast(machine)
    return { ok = paid == true, amount = paid and amount or nil, total = machine.paid }
end)

lib.callback.register('cortex-vendrobbery:shelf', function(source, id, slot)
    local machine = session(source, id, 'shelf')
    slot = whole(slot, 1, 64)
    if not machine or not slot or machine.stage ~= 'open' or not CxVendRob.has(machine.type, 'shelves') then return { ok = false } end
    if machine.items >= Config.Takings.shelfItems then return { ok = false, error = 'cap' } end
    if machine.taking then return { ok = false, error = 'busy' } end
    machine.taking = true
    local ran, paid, label, left = pcall(Robbery.payProduct, source, machine, slot)
    machine.taking = nil
    if not ran then
        print(('^1[cortex-vendrobbery]^7 shelf pull on machine %d failed: %s'):format(machine.id, tostring(paid)))
        return { ok = false, error = 'busy' }
    end
    if not paid then
        if machines[machine.id] == machine and label == 'empty' and Robbery.stockLeft(machine) == 0 and machines[machine.id] == machine and machine.worker == source then
            machine.shelvesEmpty = true
            settleSpent(source, machine)
            Robbery.broadcast(machine)
        end
        return { ok = false, error = label }
    end
    if machines[machine.id] ~= machine then return { ok = true, label = label } end
    machine.items = machine.items + 1
    acted(machine)
    if left == 0 then machine.shelvesEmpty = true end
    settleSpent(source, machine)
    Robbery.broadcast(machine)
    return { ok = true, label = label, left = machine.shelvesEmpty and 0 or Config.Takings.shelfItems - machine.items }
end)

lib.callback.register('cortex-vendrobbery:repair', function(source, id)
    id = math.tointeger(id)
    local machine = id and machines[id]
    if not machine or limited(source, 'repair') then return fail('invalid') end
    local ped = fit(source)
    if not ped or #(GetEntityCoords(ped) - machine.at) > CxVendRob.Reach then return fail('far') end
    if GetPlayerRoutingBucket(source) ~= machine.bucket then return fail('invalid') end
    if machine.vendex or machine.owner ~= Robbery.citizenid(source) then return fail('invalid') end
    if machine.worker then return fail('taken') end
    if machine.stage == 'lock' or machine.repairing then return fail('invalid') end
    local cost = Config.Repair.ownerCost
    machine.repairing = true
    local charged = Robbery.charge(source, cost)
    machine.repairing = nil
    if not charged then return fail('cash', { cost = cost }) end
    Robbery.audit(source, 'owner repaired', machine, ('$%d'):format(cost))
    if machines[machine.id] == machine then Robbery.remove(machine) end
    return { ok = true, cost = cost }
end)

RegisterNetEvent('cortex-vendrobbery:server:leave', function()
    Robbery.release(source)
end)

RegisterNetEvent('cortex-vendrobbery:server:sync', function()
    local src = source
    if limited(src, 'sync') then return end
    Robbery.sendAll(src)
end)

AddEventHandler('playerDropped', function()
    lastAction[source] = nil
end)
