local machines = Robbery.machines

local function reply(source, text)
    if source == 0 then
        print(('[cortex-vendrobbery] %s'):format(text))
        return
    end
    TriggerClientEvent('chat:addMessage', source, { args = { 'Vending Robbery', text } })
end

local function describe(machine)
    return ('#%d %s %s%s at %.1f, %.1f, %.1f | $%d and %d items taken | strikes %d%s%s%s'):format(machine.id, machine.type, machine.stage,
        machine.route and (' by ' .. machine.route) or '', machine.at.x, machine.at.y, machine.at.z, machine.paid, machine.items, machine.strikes,
        machine.worker and (' | worked by ' .. machine.worker) or '', machine.jammed and ' | lock jammed' or '', machine.seized and ' | box seized' or '')
end

local commands = {}

function commands.list(source)
    local count = 0
    for _, machine in pairs(machines) do
        count = count + 1
        reply(source, describe(machine))
    end
    if count == 0 then reply(source, 'No vending machines are broken into.') end
end

function commands.reset(source, target)
    if target == 'all' then
        local list = {}
        for _, machine in pairs(machines) do list[#list + 1] = machine end
        for _, machine in ipairs(list) do
            Robbery.clearMachineCooldown(machine.id)
            Robbery.remove(machine)
        end
        Robbery.audit(source ~= 0 and source or nil, 'admin reset', nil, ('%d machines'):format(#list))
        reply(source, ('Repaired %d machines.'):format(#list))
        return
    end
    local id = math.tointeger(tonumber(target))
    if not id then
        reply(source, 'Usage: /vendrob reset <machine id|all>  (see /vendrob list)')
        return
    end
    Robbery.clearMachineCooldown(id)
    local machine = machines[id]
    if machine then
        Robbery.remove(machine)
        Robbery.audit(source ~= 0 and source or nil, 'admin reset', machine)
    end
    reply(source, ('Machine #%d is repaired and can be robbed again.'):format(id))
end

function commands.cooldown(source, target)
    local player = math.tointeger(tonumber(target))
    if not player or not GetPlayerName(player) then
        reply(source, 'Usage: /vendrob cooldown <server id>')
        return
    end
    Robbery.clearCooldown(player)
    Robbery.audit(source ~= 0 and source or nil, 'admin cleared cooldown', nil, GetPlayerName(player))
    reply(source, ('Cleared the robbery cooldown for %s.'):format(GetPlayerName(player)))
end

RegisterCommand('vendrob', function(source, args)
    local run = commands[args[1] or '']
    if not run then
        reply(source, 'Usage: /vendrob list | reset <machine id|all> | cooldown <server id>')
        return
    end
    run(source, args[2])
end, true)
