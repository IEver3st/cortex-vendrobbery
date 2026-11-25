Camera = {}

local SWAY = 0.014
local GLIDE_MS = 700

local cam
local rec
local current = {}
local glide
local sway = { x = 0.0, y = 0.0, gx = 0.0, gy = 0.0 }
local light = true

function Camera.setLight(on) light = on == true end

local function reduced()
    local ok, value = pcall(lib.getSetting, 'reducedMotion')
    return ok and value == true
end

local function viewFor(name)
    local views = rec.def.views
    return views[name] or views.open
end

local function worldOf(p)
    return World.point(rec, p.x, p.y, p.z)
end

local function apply(pos, target, fov)
    if not cam then return end
    local view = Geo.setView(pos, target, fov)
    SetCamCoord(cam, pos.x, pos.y, pos.z)
    SetCamRot(cam, view.pitch, 0.0, view.yaw, 2)
    SetCamFov(cam, fov)
end

function Camera.active() return cam ~= nil end

function Camera.enter(r, name)
    Camera.exit(true)
    rec = r
    local view = viewFor(name)
    local pos, target = worldOf(view.pos), worldOf(view.target)
    local fov = Config.Camera.fov + 0.0
    cam = CreateCamWithParams('DEFAULT_SCRIPTED_CAMERA', pos.x, pos.y, pos.z, 0.0, 0.0, 0.0, fov, false, 2)
    current = { pos = pos, target = target, fov = fov, localPos = view.pos, localTarget = view.target }
    apply(pos, target, fov)
    SetCamActive(cam, true)
    local ease = not reduced()
    RenderScriptCams(true, ease, ease and 700 or 0, true, false)
    Camera.readyAt = GetGameTimer() + (ease and 760 or 60)
    Camera.loop()
end

function Camera.stage(name)
    if not cam then return end
    local view = viewFor(name)
    glide = { started = GetGameTimer(), ms = reduced() and 0 or GLIDE_MS, fromPos = current.localPos, fromTarget = current.localTarget,
        toPos = view.pos, toTarget = view.target }
end

function Camera.sway(nx, ny)
    sway.gx = Geo.clamp((nx - 0.5) * 2.0, -1.0, 1.0)
    sway.gy = Geo.clamp((ny - 0.5) * 2.0, -1.0, 1.0)
end

function Camera.shake(kind, amount)
    if cam then ShakeCam(cam, kind or 'SMALL_EXPLOSION_SHAKE', (amount or 0.08) + 0.0) end
end

function Camera.loop()
    local mine = cam
    CreateThread(function()
        while cam == mine do
            local lp, lt = current.localPos, current.localTarget
            if glide then
                local t = glide.ms > 0 and Geo.clamp((GetGameTimer() - glide.started) / glide.ms, 0.0, 1.0) or 1.0
                local k = Geo.ease(t)
                lp = glide.fromPos + (glide.toPos - glide.fromPos) * k
                lt = glide.fromTarget + (glide.toTarget - glide.fromTarget) * k
                if t >= 1.0 then glide = nil end
                current.localPos, current.localTarget = lp, lt
            end
            local k = 1.0 - math.exp(-6.0 * GetFrameTime())
            sway.x = sway.x + (sway.gx - sway.x) * k
            sway.y = sway.y + (sway.gy - sway.y) * k
            local offset = reduced() and vector3(0.0, 0.0, 0.0) or vector3(sway.x * SWAY, 0.0, -sway.y * SWAY * 0.6)
            local pos, target = worldOf(lp + offset), worldOf(lt + offset * 0.35)
            current.pos, current.target = pos, target
            apply(pos, target, current.fov)
            SetEntityLocallyInvisible(PlayerPedId())
            HideHudAndRadarThisFrame()
            if light and Config.Camera.workLight then
                local above = pos + vector3(0.0, 0.0, 0.08)
                DrawLightWithRange(above.x, above.y, above.z, 255, 241, 224, 1.6, 1.4)
            end
            Wait(0)
        end
    end)
end

function Camera.exit(instant)
    if not cam then return end
    local old = cam
    cam, rec, glide = nil, nil, nil
    Geo.view = nil
    local ease = not instant and not reduced()
    RenderScriptCams(false, ease, ease and 600 or 0, true, false)
    if ease then
        SetTimeout(650, function() if DoesCamExist(old) then DestroyCam(old, false) end end)
    else
        DestroyCam(old, false)
    end
end

AddEventHandler('onResourceStop', function(name)
    if name ~= Rob.resource or not cam then return end
    pcall(RenderScriptCams, false, false, 0, true, false)
    pcall(DestroyCam, cam, false)
end)
