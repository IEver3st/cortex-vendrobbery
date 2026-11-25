local TAG = '^3[cortex-vendrobbery]^7 config.lua: '

local function want(path, value, expected, default)
    if type(value) == expected then return value end
    print(('%s%s expected %s, got %s; using %s'):format(TAG, path, expected, type(value), tostring(default)))
    return default
end

local function section(name)
    if type(Config[name]) ~= 'table' then
        if Config[name] ~= nil then
            print(('%sConfig.%s expected table, got %s; using defaults'):format(TAG, name, type(Config[name])))
        end
        Config[name] = {}
    end
    return Config[name]
end

local function number(path, tbl, key, default, low, high)
    local value = want(path, tbl[key], 'number', default)
    if value ~= value or value < low or value > high then
        print(('%s%s must be %s to %s, got %s; using %s'):format(TAG, path, low, high, tostring(value), default))
        value = default
    end
    tbl[key] = value
end

local function whole(path, tbl, key, default, low, high)
    number(path, tbl, key, default, low, high)
    if tbl[key] ~= math.floor(tbl[key]) then
        print(('%s%s must be a whole number, got %s; using %s'):format(TAG, path, tbl[key], default))
        tbl[key] = default
    end
end

local function flag(path, tbl, key, default)
    tbl[key] = want(path, tbl[key], 'boolean', default)
end

local function itemName(path, tbl, key, default)
    if tbl[key] == false then return end
    tbl[key] = want(path, tbl[key], 'string', default)
end

local function band(path, tbl, key, default, low, high, gap)
    local v = tbl[key]
    if type(v) ~= 'table' or type(v[1]) ~= 'number' or type(v[2]) ~= 'number' or v[1] < low or v[2] > high or v[2] - v[1] < gap then
        if v ~= nil then
            print(('%s%s expected { low, high } inside %s to %s and at least %s apart; using { %s, %s }'):format(TAG, path, low, high, gap, default[1], default[2]))
        end
        tbl[key] = { default[1], default[2] }
    end
end

Config.Locale = want('Config.Locale', Config.Locale, 'string', 'en')
whole('Config.Strikes', Config, 'Strikes', 3, 1, 6)

local keys = section('Keys')
keys.start = want('Config.Keys.start', keys.start, 'string', 'G')

local tools = section('Tools')
itemName('Config.Tools.crowbar', tools, 'crowbar', 'WEAPON_CROWBAR')
itemName('Config.Tools.pick', tools, 'pick', 'vend_pickset')
itemName('Config.Tools.drill', tools, 'drill', 'vend_drill')

local targets = section('Targets')
flag('Config.Targets.vendex', targets, 'vendex', true)
flag('Config.Targets.player', targets, 'player', true)
flag('Config.Targets.ownerOnline', targets, 'ownerOnline', true)

local police = section('Police')
whole('Config.Police.required', police, 'required', 0, 0, 64)
police.jobType = want('Config.Police.jobType', police.jobType, 'string', 'leo')
number('Config.Police.witnessChance', police, 'witnessChance', 0.35, 0, 1)
police.send = want('Config.Police.send', police.send, 'function', function() end)

local cooldown = section('Cooldown')
number('Config.Cooldown.playerMinutes', cooldown, 'playerMinutes', 15, 0, 1440)
number('Config.Cooldown.machineMinutes', cooldown, 'machineMinutes', 45, 0, 10080)
number('Config.Cooldown.repairMinutes', cooldown, 'repairMinutes', 30, 1, 1440)
number('Config.Cooldown.pryRepairMinutes', cooldown, 'pryRepairMinutes', 20, 0, 1440)
number('Config.Cooldown.abandonMinutes', cooldown, 'abandonMinutes', 5, 1, 120)
number('Config.Cooldown.retrySeconds', cooldown, 'retrySeconds', 60, 0, 3600)

local alarm = section('Alarm')
number('Config.Alarm.seconds', alarm, 'seconds', 45, 5, 600)

local pry = section('Pry')
band('Config.Pry.zone', pry, 'zone', { 0.60, 0.82 }, 0.2, 0.92, 0.08)
number('Config.Pry.holdMs', pry, 'holdMs', 900, 200, 5000)
number('Config.Pry.slipAt', pry, 'slipAt', 0.96, pry.zone[2] + 0.04, 1.0)

local pick = section('Pick')
band('Config.Pick.torque', pick, 'torque', { 0.42, 0.68 }, 0.15, 0.9, 0.1)
number('Config.Pick.breakAt', pick, 'breakAt', 0.95, pick.torque[2] + 0.04, 1.0)
number('Config.Pick.window', pick, 'window', 0.07, 0.03, 0.08)
number('Config.Pick.bindMs', pick, 'bindMs', 450, 100, 3000)

local drill = section('Drill')
band('Config.Drill.zone', drill, 'zone', { 0.50, 0.78 }, 0.2, 0.92, 0.1)
number('Config.Drill.seconds', drill, 'seconds', 9, 2, 60)
number('Config.Drill.snapAt', drill, 'snapAt', 0.97, drill.zone[2] + 0.04, 1.0)
number('Config.Drill.heatPerSecond', drill, 'heatPerSecond', 0.30, 0.02, 2)
number('Config.Drill.coolPerSecond', drill, 'coolPerSecond', 0.36, 0.02, 2)

local takings = section('Takings')
number('Config.Takings.stackerShare', takings, 'stackerShare', 0.35, 0, 1)
number('Config.Takings.playerShare', takings, 'playerShare', 0.5, 0, 1)
whole('Config.Takings.playerMax', takings, 'playerMax', 2500, 0, 10000000)
number('Config.Takings.vendexShare', takings, 'vendexShare', 0.5, 0, 1)
whole('Config.Takings.vendexMax', takings, 'vendexMax', 1500, 0, 10000000)
whole('Config.Takings.drawerSlots', takings, 'drawerSlots', 8, 1, 12)
whole('Config.Takings.shelfItems', takings, 'shelfItems', 24, 0, 500)
if type(takings.vendexFloat) ~= 'table' or type(takings.vendexFloat[1]) ~= 'number' or type(takings.vendexFloat[2]) ~= 'number'
    or takings.vendexFloat[1] < 0 or takings.vendexFloat[1] > takings.vendexFloat[2] then
    if takings.vendexFloat ~= nil then print(TAG .. 'Config.Takings.vendexFloat expected { min, max } with min <= max; using { 40, 220 }') end
    takings.vendexFloat = { 40, 220 }
end
takings.vendexFloat[1], takings.vendexFloat[2] = math.floor(takings.vendexFloat[1]), math.floor(takings.vendexFloat[2])

local reward = section('Reward')
reward.item = want('Config.Reward.item', reward.item, 'string', 'money')

local repair = section('Repair')
whole('Config.Repair.ownerCost', repair, 'ownerCost', 150, 0, 10000000)

local camera = section('Camera')
number('Config.Camera.fov', camera, 'fov', 40.0, 20, 70)
camera.workLight = want('Config.Camera.workLight', camera.workLight, 'boolean', true)
