World = { recs = {} }

local VEND = 'cortex-vending'
local PARTS_MS = 400

local function vend(name, ...)
    if GetResourceState(VEND) ~= 'started' then return nil end
    local args = table.pack(...)
    local ok, result = pcall(function() return exports[VEND][name](exports[VEND], table.unpack(args, 1, args.n)) end)
    return ok and result or nil
end
World.vend = vend

function World.get(id) return World.recs[id] end

function World.near(range)
    local near = vend('MachineNear', range)
    if type(near) ~= 'table' or not CxVendRob.Machines[near.type] then return nil end
    return near
end

function World.parts(rec, force)
    local now = GetGameTimer()
    local p = rec.parts
    if not force and p and now - (rec.partsAt or 0) < PARTS_MS and DoesEntityExist(p.entity) then return p end
    p = vend('MachineParts', rec.id)
    rec.parts, rec.partsAt = type(p) == 'table' and p or nil, now
    return rec.parts
end

function World.point(rec, x, y, z)
    local p = rec.parts
    if not p or not DoesEntityExist(p.entity) then return rec.at + vector3(0.0, 0.0, z + 0.0) end
    return GetOffsetFromEntityInWorldCoords(p.entity, x + 0.0, y + 0.0, z + 0.0)
end

function World.doorPoint(rec, x, y, z)
    local p = rec.parts
    local h = rec.def.door.hinge
    if not p or not p.door or not DoesEntityExist(p.door) then return World.point(rec, x, y, z) end
    return GetOffsetFromEntityInWorldCoords(p.door, x - h.x, y - h.y, z - h.z)
end

function World.at(rec, v)
    return World.point(rec, v.x, v.y, v.z)
end

function World.normal(rec)
    return Geo.norm(World.point(rec, 0.0, -1.0, 0.0) - World.point(rec, 0.0, 0.0, 0.0))
end

function World.products(rec)
    local now = GetGameTimer()
    if rec.products and now - (rec.productsAt or 0) < 300 then return rec.products end
    local list = vend('MachineProducts', rec.id)
    rec.products, rec.productsAt = type(list) == 'table' and list or {}, now
    return rec.products
end

function World.apply(id, snap)
    local rec = World.recs[id]
    if type(snap) ~= 'table' then
        if rec then
            World.recs[id] = nil
            Fx.forget(id)
            if Session then Session.removed(id) end
        end
        return
    end
    local def = CxVendRob.Machines[snap.type]
    if not def then return end
    local old = rec and rec.snap
    if not rec then
        rec = { id = id, def = def, notes = {} }
        World.recs[id] = rec
    end
    rec.snap = snap
    rec.at = vector3(snap.coords.x + 0.0, snap.coords.y + 0.0, snap.coords.z + 0.0)
    if (snap.alarmLeft or 0) > 0 then
        Fx.alarm(id, rec.at + vector3(0.0, 0.0, 1.2), snap.alarmLeft)
    elseif old and (old.alarmLeft or 0) > 0 then
        Fx.alarm(id, rec.at, 0)
    end
    if Session then Session.updated(rec, old) end
end

RegisterNetEvent('cortex-vendrobbery:client:machine', function(id, snap)
    World.apply(id, snap)
end)

RegisterNetEvent('cortex-vendrobbery:client:all', function(list)
    local seen = {}
    for _, snap in ipairs(type(list) == 'table' and list or {}) do
        seen[snap.id] = true
        World.apply(snap.id, snap)
    end
    for id in pairs(World.recs) do
        if not seen[id] then World.apply(id, nil) end
    end
end)

CreateThread(function()
    Wait(1500)
    TriggerServerEvent('cortex-vendrobbery:server:sync')
end)

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    TriggerServerEvent('cortex-vendrobbery:server:sync')
end)

AddEventHandler('onResourceStop', function(name)
    if name ~= VEND then return end
    local ids = {}
    for id in pairs(World.recs) do ids[#ids + 1] = id end
    for _, id in ipairs(ids) do World.apply(id, nil) end
end)
