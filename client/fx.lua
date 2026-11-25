Fx = {}

local HEAR = 45.0
local ALARM_HEAR = 90.0
local SPARK_ASSET, SPARK_FX = 'core', 'ent_brk_sparking_wires'

Fx.SOUNDS = {
    tick = { 'NAV_UP_DOWN', 'HUD_FRONTEND_DEFAULT_SOUNDSET', ui = true },
    tool = { 'SELECT', 'HUD_FRONTEND_DEFAULT_SOUNDSET', ui = true },
    locked = { 'ERROR', 'HUD_FRONTEND_DEFAULT_SOUNDSET', ui = true },
    bite = { 'Click', 'DLC_HEIST_HACKING_SNAKE_SOUNDS' },
    creak = { 'tumbler_turn', 'SAFE_CRACK_SOUNDSET' },
    pop = { 'Drill_Pin_Break', 'DLC_HEIST_FLEECA_SOUNDSET' },
    clang = { 'Drill_Pin_Break', 'DLC_HEIST_FLEECA_SOUNDSET' },
    bind = { 'tumbler_pin_fall', 'SAFE_CRACK_SOUNDSET' },
    set = { 'Pin_Good', 'DLC_HEIST_BIOLAB_PREP_HACKING_SOUNDS' },
    overset = { 'Pin_Bad', 'DLC_HEIST_BIOLAB_PREP_HACKING_SOUNDS' },
    open = { 'tumbler_pin_fall_final', 'SAFE_CRACK_SOUNDSET' },
    drill = { 'Drill_Pin_Break', 'DLC_HEIST_FLEECA_SOUNDSET' },
    snap = { 'Hack_Failed', 'DLC_HEIST_BIOLAB_PREP_HACKING_SOUNDS' },
    grip = { 'Click', 'DLC_HEIST_HACKING_SNAKE_SOUNDS' },
    grab = { 'PICK_UP', 'HUD_FRONTEND_DEFAULT_SOUNDSET' },
    lockout = { 'Hack_Failed', 'DLC_HEIST_BIOLAB_PREP_HACKING_SOUNDS' },
    alarm = { 'Beep_Red', 'DLC_HEIST_HACKING_SNAKE_SOUNDS' },
}

local alarms = {}

local function heard(at, range)
    return #(GetFinalRenderedCamCoord() - at) <= range
end

function Fx.sound(name, at)
    local s = Fx.SOUNDS[name]
    if not s then return end
    if s.ui or not at then
        PlaySoundFrontend(-1, s[1], s[2], true)
        return
    end
    if not heard(at, HEAR) then return end
    PlaySoundFromCoord(-1, s[1], at.x, at.y, at.z, s[2], false, 20, false)
end

function Fx.frontend(name, set)
    PlaySoundFrontend(-1, name, set, true)
end

function Fx.sparks(at, scale)
    if not at or not Rob.loadPtfx(SPARK_ASSET) then return end
    UseParticleFxAsset(SPARK_ASSET)
    StartParticleFxNonLoopedAtCoord(SPARK_FX, at.x, at.y, at.z, 0.0, 0.0, 0.0, (scale or 0.35) + 0.0, false, false, false)
end

function Fx.alarm(id, at, seconds)
    if seconds <= 0 then
        alarms[id] = nil
        return
    end
    alarms[id] = { at = at, untilAt = GetGameTimer() + math.floor(seconds * 1000) }
end

function Fx.alarmLeft(id)
    local a = alarms[id]
    if not a then return 0 end
    return math.max(0, a.untilAt - GetGameTimer())
end

function Fx.forget(id)
    alarms[id] = nil
end

CreateThread(function()
    local s = Fx.SOUNDS.alarm
    while true do
        local now = GetGameTimer()
        local any = false
        for id, a in pairs(alarms) do
            if now >= a.untilAt then
                alarms[id] = nil
            else
                any = true
                if heard(a.at, ALARM_HEAR) then
                    PlaySoundFromCoord(-1, s[1], a.at.x, a.at.y, a.at.z, s[2], false, 60, false)
                end
            end
        end
        Wait(any and 420 or 1000)
    end
end)
