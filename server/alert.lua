Robbery = Robbery or {}

local function player(source)
    local ok, p = pcall(function() return exports.qbx_core:GetPlayer(source) end)
    if ok and type(p) == 'table' and p.PlayerData then return p end
    return nil
end

local function playerName(source)
    local p = player(source)
    if p then
        local info = p.PlayerData.charinfo or {}
        return ('%s %s (%s)'):format(info.firstname or '?', info.lastname or '?', p.PlayerData.citizenid or '?')
    end
    return GetPlayerName(source) or ('player %s'):format(source)
end

function Robbery.identity(source)
    return GetPlayerIdentifierByType(source, 'license2') or GetPlayerIdentifierByType(source, 'license') or ('src:%s'):format(source)
end

function Robbery.citizenid(source)
    local p = player(source)
    return p and p.PlayerData.citizenid or nil
end

function Robbery.sourceOf(citizenid)
    if type(citizenid) ~= 'string' then return nil end
    local ok, p = pcall(function() return exports.qbx_core:GetPlayerByCitizenId(citizenid) end)
    if ok and type(p) == 'table' and p.PlayerData then return p.PlayerData.source end
    return nil
end

function Robbery.restrained(source)
    local p = player(source)
    if not p then return false end
    local meta = p.PlayerData.metadata or {}
    return meta.isdead or meta.inlaststand or meta.ishandcuffed or false
end

function Robbery.policeOnDuty()
    local ok, count = pcall(function() return exports.qbx_core:GetDutyCountType(Config.Police.jobType) end)
    return ok and tonumber(count) or 0
end

function Robbery.audit(source, action, machine, detail)
    local who = source and playerName(source) or 'system'
    local where = machine and ('machine %d (%s%s) at %.1f, %.1f, %.1f'):format(machine.id, machine.type, machine.vendex and ', Vendex' or (', owner ' .. tostring(machine.owner)),
        machine.at.x, machine.at.y, machine.at.z) or '-'
    local line = ('%s | %s | %s%s'):format(who, action, where, detail and (' | ' .. detail) or '')
    print(('^5[cortex-vendrobbery]^7 %s'):format(line))
    local hook = GetConvar('cortex_vendrobbery_webhook', '')
    if hook == '' then return end
    PerformHttpRequest(hook, function() end, 'POST', json.encode({ username = 'Cortex Vending Robbery', content = line:sub(1, 1900) }),
        { ['Content-Type'] = 'application/json' })
end

function Robbery.alert(source, machine, kind)
    local now = os.time()
    machine.alertedAt = machine.alertedAt or {}
    if machine.alertedAt[kind] and now - machine.alertedAt[kind] < 60 then return end
    machine.alertedAt[kind] = now
    local data = { kind = kind, coords = machine.at, machine = L(CxVendRob.Machines[machine.type].label) }
    local ok, problem = pcall(Config.Police.send, source, data)
    if not ok then print(('^3[cortex-vendrobbery]^7 Config.Police.send failed: %s'):format(problem)) end
    Robbery.audit(source, kind == 'alarm' and 'alarm' or 'witness report', machine)
end

function Robbery.tellOwner(machine, key, ...)
    if machine.vendex then return end
    local src = Robbery.sourceOf(machine.owner)
    if not src then return end
    TriggerClientEvent('cortex-lib:notify', src, { type = 'error', title = L('owner.title'), description = L(key, ...) })
end
