Vending = {}

local RES = 'cortex-vending'
local API = 1
local warned = {}

local function warn(key, text)
    if warned[key] then return end
    warned[key] = true
    print(('^1[cortex-vendrobbery]^7 %s'):format(text))
end

local function call(name, ...)
    if GetResourceState(RES) ~= 'started' then return nil end
    local args = table.pack(...)
    local results = table.pack(pcall(function() return exports[RES][name](exports[RES], table.unpack(args, 1, args.n)) end))
    if not results[1] then
        warn(name, ('cortex-vending has no %s export. Update cortex-vending to the version with the tamper API. (%s)'):format(name, tostring(results[2])))
        return nil
    end
    return table.unpack(results, 2, results.n)
end

function Vending.ready()
    if GetResourceState(RES) ~= 'started' then return false end
    local api, allowed = call('TamperApi')
    if tonumber(api) ~= API then
        warn('api', ('this cortex-vending speaks tamper API %s, this addon needs %d. Update whichever is older.'):format(tostring(api), API))
        return false
    end
    if allowed ~= true then
        warn('allow', "cortex-vending refuses this resource. Add ['cortex-vendrobbery'] = true to Config.Tamper.Allow in cortex-vending/shared/config.lua.")
        return false
    end
    return true
end

function Vending.info(id, actor)
    local info = call('TamperInfo', id, actor)
    return type(info) == 'table' and info or nil
end

function Vending.hold(id, state)
    local ok, why = call('TamperHold', id, state)
    return ok == true, why
end

function Vending.takeCash(id, amount, actor)
    local taken, ref, err = call('TamperTakeCash', id, amount, actor)
    taken = math.max(0, math.floor(tonumber(taken) or 0))
    if taken == 0 then return 0, nil, err or 'failed' end
    return taken, ref
end

function Vending.takeStock(id, slot, actor)
    local item, ref, err = call('TamperTakeStock', id, slot, actor)
    if type(item) ~= 'string' then return nil, nil, err or 'failed' end
    return item, ref
end

function Vending.settle(id, ref, outcome)
    return call('TamperSettle', id, ref, outcome) == true
end
