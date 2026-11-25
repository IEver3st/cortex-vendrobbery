Pointer = { fake = nil }

local ws = lib.worldScreen

function Pointer.pos()
    if Pointer.fake then return Pointer.fake.x, Pointer.fake.y end
    local px, py = ws.cursor()
    local w, h = GetActiveScreenResolution()
    return (px or w * 0.5) / math.max(1, w), (py or h * 0.5) / math.max(1, h)
end

function Pointer.onPlane(nx, ny, point, normal)
    local origin, dir = Geo.ray(nx, ny)
    if not origin then return nil end
    return Geo.hitPlane(origin, dir, point, normal)
end

function Pointer.nearest(nx, ny, list, radius)
    local best, bestD
    local limit = radius * Geo.scale()
    for i, item in ipairs(list) do
        if item.at and not item.skip then
            local sx, sy = Geo.project(item.at)
            if sx then
                local d = Geo.pixels(nx, ny, sx, sy)
                if d <= limit and (not bestD or d < bestD) then best, bestD = i, d end
            end
        end
    end
    return best, bestD
end

function Pointer.nearestPath(nx, ny, paths, radius)
    local best, bestD, bestPoint
    local limit = radius * Geo.scale()
    for i, path in ipairs(paths) do
        if path and not path.skip then
            local prevX, prevY, prevW
            for _, w in ipairs(path) do
                local sx, sy = Geo.project(w)
                if sx and prevX then
                    local d, t = Geo.segmentPixels(nx, ny, prevX, prevY, sx, sy)
                    if d <= limit and (not bestD or d < bestD) then
                        best, bestD, bestPoint = i, d, prevW + (w - prevW) * t
                    end
                end
                prevX, prevY, prevW = sx, sy, w
            end
        end
    end
    return best, bestD, bestPoint
end

function Pointer.screen(at)
    local sx, sy = Geo.project(at)
    if not sx then return nil end
    return { x = sx, y = sy }
end
