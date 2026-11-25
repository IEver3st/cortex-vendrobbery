Geo = {}

function Geo.v3(t)
    if not t then return nil end
    return vector3((t.x or 0) + 0.0, (t.y or 0) + 0.0, (t.z or 0) + 0.0)
end

function Geo.dot(a, b) return a.x * b.x + a.y * b.y + a.z * b.z end

function Geo.cross(a, b)
    return vector3(a.y * b.z - a.z * b.y, a.z * b.x - a.x * b.z, a.x * b.y - a.y * b.x)
end

function Geo.norm(v)
    local l = #v
    if l < 1e-6 then return vector3(0.0, 1.0, 0.0) end
    return v / l
end

function Geo.clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

function Geo.lerp(a, b, t) return a + (b - a) * t end

function Geo.ease(t)
    t = Geo.clamp(t, 0.0, 1.0)
    return t < 0.5 and 4 * t * t * t or 1 - (-2 * t + 2) ^ 3 / 2
end

local function rotationAxes(rot)
    local p, r, y = math.rad(rot.x), math.rad(rot.y), math.rad(rot.z)
    local cp, sp, cr, sr, cy, sy = math.cos(p), math.sin(p), math.cos(r), math.sin(r), math.cos(y), math.sin(y)
    local right = vector3(cr * cy - sr * sp * sy, cr * sy + sr * sp * cy, -sr * cp)
    local forward = vector3(-cp * sy, cp * cy, sp)
    local up = vector3(sr * cy + cr * sp * sy, sr * sy - cr * sp * cy, cr * cp)
    return right, forward, up
end

function Geo.frame(coords, rot, origin)
    local right, forward, up = rotationAxes(rot)
    local base = Geo.v3(coords)
    local o = origin or vector3(0.0, 0.0, 0.0)
    local at = base + right * o.x + forward * o.y + up * o.z
    return { at = at, right = right, forward = forward, up = up, rot = Geo.v3(rot), base = base, origin = o }
end

function Geo.toWorld(f, x, y, z)
    return f.at + f.right * x + f.forward * y + f.up * z
end

function Geo.toLocal(f, p)
    local d = p - f.at
    return vector3(Geo.dot(d, f.right), Geo.dot(d, f.forward), Geo.dot(d, f.up))
end

function Geo.dirToWorld(f, x, y, z)
    return f.right * x + f.forward * y + f.up * z
end

Geo.view = nil

function Geo.setView(pos, target, fov)
    local d = target - pos
    local flat = math.sqrt(d.x * d.x + d.y * d.y)
    local yaw = math.deg(math.atan(-d.x, d.y))
    local pitch = math.deg(math.atan(d.z, flat))
    local forward = Geo.norm(d)
    local right = Geo.norm(Geo.cross(forward, vector3(0.0, 0.0, 1.0)))
    local up = Geo.cross(right, forward)
    local w, h = GetActiveScreenResolution()
    Geo.view = {
        pos = pos, target = target, fov = fov, pitch = pitch, yaw = yaw,
        forward = forward, right = right, up = up,
        tan = math.tan(math.rad(fov) * 0.5), aspect = w / math.max(1, h), w = w, h = h,
    }
    return Geo.view
end

function Geo.project(p)
    local v = Geo.view
    if not v then return nil end
    local d = p - v.pos
    local depth = Geo.dot(d, v.forward)
    if depth < 0.02 then return nil end
    local x = Geo.dot(d, v.right) / (depth * v.tan * v.aspect)
    local y = Geo.dot(d, v.up) / (depth * v.tan)
    return 0.5 + x * 0.5, 0.5 - y * 0.5, depth
end

function Geo.ray(sx, sy)
    local v = Geo.view
    if not v then return nil end
    local x = (sx - 0.5) * 2.0 * v.tan * v.aspect
    local y = (0.5 - sy) * 2.0 * v.tan
    return v.pos, Geo.norm(v.forward + v.right * x + v.up * y)
end

function Geo.hitPlane(origin, dir, point, normal)
    local denom = Geo.dot(dir, normal)
    if math.abs(denom) < 1e-5 then return nil end
    local t = Geo.dot(point - origin, normal) / denom
    if t < 0 then return nil end
    return origin + dir * t
end

function Geo.pixels(ax, ay, bx, by)
    local v = Geo.view
    local w, h = v and v.w or 1920, v and v.h or 1080
    local dx, dy = (ax - bx) * w, (ay - by) * h
    return math.sqrt(dx * dx + dy * dy)
end

function Geo.segmentPixels(px, py, ax, ay, bx, by)
    local v = Geo.view
    local w, h = v and v.w or 1920, v and v.h or 1080
    px, py, ax, ay, bx, by = px * w, py * h, ax * w, ay * h, bx * w, by * h
    local vx, vy = bx - ax, by - ay
    local len = vx * vx + vy * vy
    local t = len > 0 and Geo.clamp(((px - ax) * vx + (py - ay) * vy) / len, 0.0, 1.0) or 0.0
    local cx, cy = ax + vx * t, ay + vy * t
    return math.sqrt((px - cx) ^ 2 + (py - cy) ^ 2), t
end

function Geo.scale()
    local v = Geo.view
    return (v and v.h or 1080) / 1080
end
