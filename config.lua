Config = {}

Config.Locale = 'en'

Config.Keys = {
    start = 'G',
}

Config.Tools = {
    crowbar = 'WEAPON_CROWBAR',
    pick = 'vend_pickset',
    drill = 'vend_drill',
}

Config.Targets = {
    vendex = true,
    player = true,
    ownerOnline = true,
}

Config.Police = {
    required = 0,
    jobType = 'leo',
    witnessChance = 0.35,
    send = function(source, data)
        if GetResourceState('cortex-dispatch') == 'started' then
            exports['cortex-dispatch']:CustomAlert({
                code = '10-90',
                title = data.kind == 'alarm' and 'Vending machine alarm' or 'Vending machine tampering',
                message = data.kind == 'alarm' and ('Door alarm from a %s.'):format(data.machine)
                    or ('Someone is breaking into a %s.'):format(data.machine),
                priority = data.kind == 'alarm' and 1 or 2,
                coords = data.coords,
                category = 'robbery',
                jobs = { 'leo' },
            })
            return
        end
        TriggerEvent('police:server:policeAlert', data.kind == 'alarm' and 'Vending machine alarm' or 'Vending machine tampering', nil, source)
    end,
}

Config.Cooldown = {
    playerMinutes = 15,
    machineMinutes = 45,
    repairMinutes = 30,
    pryRepairMinutes = 20,
    abandonMinutes = 5,
    retrySeconds = 60,
}

Config.Strikes = 3

Config.Alarm = {
    seconds = 45,
}

Config.Pry = {
    zone = { 0.60, 0.82 },
    holdMs = 900,
    slipAt = 0.96,
}

Config.Pick = {
    torque = { 0.42, 0.68 },
    breakAt = 0.95,
    window = 0.07,
    bindMs = 450,
}

Config.Drill = {
    zone = { 0.50, 0.78 },
    seconds = 9,
    snapAt = 0.97,
    heatPerSecond = 0.30,
    coolPerSecond = 0.36,
}

Config.Takings = {
    stackerShare = 0.35,
    playerShare = 0.5,
    playerMax = 2500,
    vendexShare = 0.5,
    vendexMax = 1500,
    vendexFloat = { 40, 220 },
    drawerSlots = 8,
    shelfItems = 24,
}

Config.Reward = {
    item = 'money',
}

Config.Repair = {
    ownerCost = 150,
}

Config.Camera = {
    fov = 40.0,
    workLight = true,
}
