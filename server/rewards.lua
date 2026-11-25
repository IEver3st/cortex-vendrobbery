Robbery = Robbery or {}

local function inv(name, ...)
    local args = table.pack(...)
    return pcall(function() return exports.ox_inventory[name](exports.ox_inventory, table.unpack(args, 1, args.n)) end)
end

function Robbery.hasTool(source, tool)
    local item = Config.Tools[tool]
    if item == false then return true end
    local ok, held = inv('GetItemCount', source, item)
    return ok and (tonumber(held) or 0) > 0
end

function Robbery.toolLabel(tool)
    local item = Config.Tools[tool]
    if not item then return '' end
    local ok, def = inv('Items', item)
    if ok and type(def) == 'table' and def.label then return def.label end
    return item
end

local function canCarry(source, item, count)
    local ok, can = inv('CanCarryItem', source, item, count)
    return ok and can == true
end

local function give(source, item, count)
    local ok, added, reason = inv('AddItem', source, item, count)
    if not ok or reason == 'unknown_outcome' then return nil end
    return added and true or false
end

function Robbery.charge(source, amount)
    if amount <= 0 then return true end
    local ok, removed = inv('RemoveItem', source, Config.Reward.item, amount)
    return ok and removed == true
end

local function pay(source, machine, amount)
    local item = Config.Reward.item
    if not canCarry(source, item, amount) then return false, 'carry' end
    local want = math.min(amount, machine.pool)
    local minted = math.min(amount - want, machine.float)
    machine.pool = machine.pool - want
    machine.float = machine.float - minted
    local taken, ref, err = 0, nil, nil
    if want > 0 then taken, ref, err = Vending.takeCash(machine.id, want, Robbery.citizenid(source)) end
    if want > 0 and taken == 0 and err ~= 'empty' then
        machine.pool = machine.pool + want
        machine.float = machine.float + minted
        return false, 'busy'
    end
    if taken < want then machine.pool = 0 end
    local total = taken + minted
    if total <= 0 then return true, 0 end
    local given = give(source, item, total)
    if given == true then
        if ref then Vending.settle(machine.id, ref, 'done') end
        return true, total
    end
    if given == nil then
        Robbery.audit(source, 'payout unconfirmed', machine, ('$%d left the machine and the inventory did not confirm it; open in /vendissues as %s'):format(total, tostring(ref)))
        return false, 'carry', true
    end
    machine.float = machine.float + minted
    if not ref or Vending.settle(machine.id, ref, 'return') then
        machine.pool = machine.pool + taken
    else
        Robbery.audit(source, 'payout not returned', machine, ('$%d was refused by the inventory and could not go back in the box; open in /vendissues as %s'):format(taken, tostring(ref)))
    end
    return false, 'carry'
end

function Robbery.payCash(source, machine, amount)
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then return true, 0 end
    if machine.paying then return false, 'busy' end
    machine.paying = true
    local ok, paid, result, keep = pcall(pay, source, machine, amount)
    machine.paying = nil
    if not ok then
        print(('^1[cortex-vendrobbery]^7 payout on machine %d failed: %s'):format(machine.id, tostring(paid)))
        return false, 'busy', true
    end
    return paid, result, keep
end

function Robbery.payProduct(source, machine, slot)
    local info = Vending.info(machine.id)
    if not info then return false, 'busy' end
    local row = info.slots and info.slots[slot]
    if not row or not row.item or (row.stock or 0) < 1 then return false, 'empty' end
    if not canCarry(source, row.item, 1) then return false, 'carry' end
    local item, ref, err = Vending.takeStock(machine.id, slot, Robbery.citizenid(source))
    if not item then return false, err == 'empty' and 'empty' or 'busy' end
    local given = give(source, item, 1)
    if given == true then
        Vending.settle(machine.id, ref, 'done')
        local left = -1
        for _, other in ipairs(info.slots) do
            if other.item then left = left + (tonumber(other.stock) or 0) end
        end
        return true, row.label or item, math.max(0, left)
    end
    if given == nil then
        Robbery.audit(source, 'item unconfirmed', machine, ('%s left slot %d and the inventory did not confirm it; open in /vendissues as %s'):format(item, slot, tostring(ref)))
        return false, 'carry'
    end
    if not Vending.settle(machine.id, ref, 'return') then
        Robbery.audit(source, 'item not returned', machine, ('%s from slot %d could not go back; open in /vendissues as %s'):format(item, slot, tostring(ref)))
    end
    return false, 'carry'
end

function Robbery.stockLeft(machine)
    local info = Vending.info(machine.id)
    if not info then return nil end
    local n = 0
    for _, row in ipairs(info.slots or {}) do
        if row.item then n = n + (tonumber(row.stock) or 0) end
    end
    return n
end
