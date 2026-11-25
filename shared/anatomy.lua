CxVendRob = CxVendRob or {}

CxVendRob.Reach = 3.2
CxVendRob.PryPoints = 3
CxVendRob.PinCount = 7
CxVendRob.BoxPins = 4
CxVendRob.Depths = 5
CxVendRob.PickLift = 0.5

CxVendRob.Machines = {
    soda = {
        label = 'machine.soda',
        front = -0.497,
        lock = vec3(0.425, -0.515, 0.70),
        latch = { vec3(0.502, -0.46, 1.45), vec3(0.502, -0.46, 0.98), vec3(0.502, -0.46, 0.42) },
        door = { hinge = vec3(-0.505, -0.40, 0.0), open = -100.0, back = -0.385 },
        stacker = { on = 'door', at = vec3(0.41, -0.3075, 1.60), size = vec3(0.07, 0.035, 0.05) },
        box = { on = 'body', at = vec3(0.37, -0.275, 1.15), size = vec3(0.13, 0.12, 0.10), lock = vec3(0.409, -0.338, 1.13), handle = vec3(0.37, -0.341, 1.165) },
        shelves = true,
        views = {
            lock = { pos = vec3(0.395, -0.86, 0.76), target = vec3(0.425, -0.50, 0.70) },
            pry = { pos = vec3(1.50, -2.40, 1.165), target = vec3(0.50, -0.46, 0.94) },
            open = { pos = vec3(0.34, -1.86, 1.36), target = vec3(-0.22, -0.52, 1.06) },
            box = { pos = vec3(0.35, -0.80, 1.20), target = vec3(0.37, -0.30, 1.14) },
            shelves = { pos = vec3(-0.05, -1.30, 1.15), target = vec3(-0.08, -0.30, 1.05) },
        },
    },
    snack = {
        label = 'machine.snack',
        front = -0.478,
        lock = vec3(0.41, -0.4592, 0.82),
        latch = { vec3(0.482, -0.44, 1.42), vec3(0.482, -0.44, 0.96), vec3(0.482, -0.44, 0.44) },
        door = { hinge = vec3(-0.485, -0.37, 0.0), open = -100.0, back = -0.36 },
        stacker = { on = 'door', at = vec3(0.385, -0.2825, 1.13), size = vec3(0.07, 0.035, 0.05) },
        box = { on = 'body', at = vec3(0.335, -0.25, 1.03), size = vec3(0.13, 0.12, 0.10), lock = vec3(0.374, -0.313, 1.01), handle = vec3(0.335, -0.316, 1.045) },
        shelves = true,
        views = {
            lock = { pos = vec3(0.38, -0.80, 0.88), target = vec3(0.41, -0.44, 0.82) },
            pry = { pos = vec3(1.48, -2.38, 1.145), target = vec3(0.48, -0.44, 0.92) },
            open = { pos = vec3(0.32, -1.82, 1.32), target = vec3(-0.22, -0.50, 1.02) },
            box = { pos = vec3(0.32, -0.76, 1.08), target = vec3(0.335, -0.28, 1.02) },
            shelves = { pos = vec3(-0.12, -1.25, 1.10), target = vec3(-0.12, -0.30, 1.02) },
        },
    },
    coffee = {
        label = 'machine.coffee',
        front = -0.368,
        lock = vec3(0.235, -0.3592, 0.42),
        latch = { vec3(0.352, -0.34, 1.40), vec3(0.352, -0.34, 0.92), vec3(0.352, -0.34, 0.40) },
        door = { hinge = vec3(-0.355, -0.28, 0.0), open = -150.0, back = -0.27 },
        box = { on = 'body', at = vec3(0.235, -0.15, 0.52), size = vec3(0.12, 0.10, 0.10), lock = vec3(0.271, -0.203, 0.50), handle = vec3(0.235, -0.206, 0.535) },
        shelves = false,
        views = {
            lock = { pos = vec3(0.21, -0.72, 0.52), target = vec3(0.235, -0.35, 0.42) },
            pry = { pos = vec3(1.35, -2.28, 1.125), target = vec3(0.35, -0.34, 0.90) },
            open = { pos = vec3(0.30, -1.60, 1.10), target = vec3(0.0, -0.30, 0.80) },
            box = { pos = vec3(0.22, -0.66, 0.62), target = vec3(0.235, -0.18, 0.51) },
        },
    },
}

for _, def in pairs(CxVendRob.Machines) do
    if def.stacker then
        local angle = math.rad(def.door.open)
        local hinge, at = def.door.hinge, def.stacker.at
        local dx, dy = at.x - hinge.x, at.y - hinge.y
        local open = vec3(hinge.x + dx * math.cos(angle) - dy * math.sin(angle), hinge.y + dx * math.sin(angle) + dy * math.cos(angle), at.z)
        local inside = vec3(-math.sin(angle), math.cos(angle), 0.0)
        def.views.door = { pos = open + inside * 0.78 + vec3(0.0, 0.0, 0.06), target = open }
    end
end

function CxVendRob.has(machineType, part)
    local def = CxVendRob.Machines[machineType]
    if not def then return false end
    if part == 'shelves' then return def.shelves == true end
    return def[part] ~= nil
end
