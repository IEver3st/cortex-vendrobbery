Tools = {}

local T = CxVendRob.Tools or {}
local held = {}

local function quat(X, Y, Z)
    local m00, m01, m02 = X.x, Y.x, Z.x
    local m10, m11, m12 = X.y, Y.y, Z.y
    local m20, m21, m22 = X.z, Y.z, Z.z
    local trace = m00 + m11 + m22
    if trace > 0 then
        local s = 0.5 / math.sqrt(trace + 1.0)
        return (m21 - m12) * s, (m02 - m20) * s, (m10 - m01) * s, 0.25 / s
    elseif m00 > m11 and m00 > m22 then
        local s = 2.0 * math.sqrt(1.0 + m00 - m11 - m22)
        return 0.25 * s, (m01 + m10) / s, (m02 + m20) / s, (m21 - m12) / s
    elseif m11 > m22 then
        local s = 2.0 * math.sqrt(1.0 + m11 - m00 - m22)
        return (m01 + m10) / s, 0.25 * s, (m12 + m21) / s, (m02 - m20) / s
    end
    local s = 2.0 * math.sqrt(1.0 + m22 - m00 - m11)
    return (m02 + m20) / s, (m12 + m21) / s, 0.25 * s, (m10 - m01) / s
end

local function basis(z, hint, spin)
    z = Geo.norm(z)
    local x = Geo.cross(hint, z)
    if #x < 1e-4 then x = Geo.cross(vector3(0.0, 0.0, 1.0), z) end
    x = Geo.norm(x)
    local y = Geo.cross(z, x)
    if spin and spin ~= 0.0 then
        local a = math.rad(spin)
        local c, s = math.cos(a), math.sin(a)
        x, y = x * c + y * s, y * c - x * s
    end
    return x, y, z
end

local function object(slot, name)
    local want = T[name] and T[name].model
    local h = held[slot]
    if h and h.model == want and DoesEntityExist(h.obj) then return h.obj end
    if h then Rob.delete(h.obj) end
    held[slot] = nil
    if not want or not Rob.ready(want) then return nil end
    local v = Geo.view
    local obj = Rob.spawn(want, v and v.pos or GetEntityCoords(PlayerPedId()))
    if not obj then return nil end
    held[slot] = { obj = obj, model = want }
    return obj
end

function Tools.hold(slot, name, tip, dir, spin)
    local obj = object(slot, name)
    if not obj then return nil end
    local v = Geo.view
    local x, y, z = basis(dir, v and v.up or vector3(0.0, 0.0, 1.0), spin)
    SetEntityCoordsNoOffset(obj, tip.x, tip.y, tip.z, false, false, false)
    local qx, qy, qz, qw = quat(x, y, z)
    SetEntityQuaternion(obj, qx, qy, qz, qw)
    return obj
end

function Tools.drop(slot)
    local h = held[slot]
    if not h then return end
    Rob.delete(h.obj)
    held[slot] = nil
end

function Tools.dropAll()
    for slot in pairs(held) do Tools.drop(slot) end
end

function Tools.handDir(tip, side, lift)
    local v = Geo.view
    if not v then return vector3(0.0, -1.0, 0.0) end
    local hand = v.pos + v.right * (side or 0.16) - v.up * (lift or 0.16) - v.forward * 0.02
    return Geo.norm(hand - tip)
end

AddEventHandler('onResourceStop', function(name)
    if name ~= Rob.resource then return end
    for _, h in pairs(held) do pcall(Rob.delete, h.obj) end
end)
