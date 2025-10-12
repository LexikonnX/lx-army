local ESX = exports['es_extended']:getSharedObject()

local missions = {}

local function isArmy(x)
    return x and x.job and x.job.name == (Config.Job or 'army')
end

local function pickRandomDestination()
    local list = Config.AirTransport.Destinations or {}
    if #list == 0 then return nil end
    math.randomseed(GetGameTimer())
    local idx = math.random(1, #list)
    return list[idx]
end

CreateThread(function()
    math.randomseed(os.time() + math.floor(os.clock() * 1000000))
    for i = 1, 3 do math.random() end
end)

RegisterNetEvent('saa:air:start', function()
    local src = source
    local x = ESX.GetPlayerFromId(src)
    if not isArmy(x) then return end
    if missions[src] and missions[src].state and missions[src].state ~= 'done' then return end
    local dest = pickRandomDestination()
    if not dest then return end
    missions[src] = {
        state = 'spawn',
        dest = dest.id,
        heliNet = nil,
        cargoNet = nil,
        reward = dest.reward or 0
    }
    TriggerClientEvent('saa:air:started', src, { dest = dest.id })
end)

RegisterNetEvent('saa:air:setHeli', function(netId)
    local src = source
    local m = missions[src]
    if not m then return end
    m.heliNet = netId
end)

RegisterNetEvent('saa:air:setCargo', function(netId)
    local src = source
    local m = missions[src]
    if not m then return end
    m.cargoNet = netId
    TriggerClientEvent('saa:air:setCargoClient', src, netId)
end)

RegisterNetEvent('saa:air:attached', function()
    local src = source
    local m = missions[src]
    if not m or m.state ~= 'spawn' then return end
    m.state = 'enroute'
    TriggerClientEvent('saa:air:toDrop', src)
end)

RegisterNetEvent('saa:air:detached', function()
    local src = source
    local m = missions[src]
    if not m or m.state ~= 'enroute' then return end
    m.state = 'delivered'
    if m.cargoNet then
        local ent = NetworkGetEntityFromNetworkId(m.cargoNet)
        if ent and ent ~= 0 then DeleteEntity(ent) end
        m.cargoNet = nil
    end
    TriggerClientEvent('saa:air:delivered', src)
end)

local function payReward(src, amount, account)
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then return end
    account = account or 'bank'
    if account == 'bank' then
        local ok = pcall(function() xPlayer.addAccountMoney('bank', amount) end)
        if not ok then xPlayer.addMoney(amount) end
        return
    end
    if account == 'money' or account == 'cash' then
        if GetResourceState('ox_inventory') == 'started' then
            local ok = pcall(function() exports.ox_inventory:AddItem(src, 'money', amount) end)
            if ok then return end
        end
        xPlayer.addMoney(amount)
        return
    end
    local acc = xPlayer.getAccount(account)
    if acc then
        local ok = pcall(function() xPlayer.addAccountMoney(account, amount) end)
        if not ok then xPlayer.addMoney(amount) end
    else
        xPlayer.addMoney(amount)
    end
end

RegisterNetEvent('saa:air:return', function()
    local src = source
    local m = missions[src]
    if not m or m.state ~= 'delivered' then return end
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return end
    local p = GetEntityCoords(ped)
    local rz = Config.AirTransport.Start.vehicleReturn
    local rr = Config.AirTransport.Start.returnRadius or 10.0
    local dx, dy, dz = p.x - rz.x, p.y - rz.y, p.z - rz.z
    if (dx*dx + dy*dy + dz*dz) > (rr*rr) then return end
    payReward(src, m.reward or 0, Config.AirTransport.PayAccount or 'bank')
    if m.cargoNet then
        local ent = NetworkGetEntityFromNetworkId(m.cargoNet)
        if ent and ent ~= 0 then DeleteEntity(ent) end
    end
    if m.heliNet then
        local veh = NetworkGetEntityFromNetworkId(m.heliNet)
        if veh and veh ~= 0 then DeleteEntity(veh) end
    end
    m.state = 'done'
    m.heliNet = nil
    m.cargoNet = nil
    TriggerClientEvent('saa:air:finished', src, true)
end)

AddEventHandler('playerDropped', function()
    local m = missions[source]
    if not m then return end
    if m.cargoNet then
        local ent = NetworkGetEntityFromNetworkId(m.cargoNet)
        if ent and ent ~= 0 then DeleteEntity(ent) end
    end
    if m.heliNet then
        local veh = NetworkGetEntityFromNetworkId(m.heliNet)
        if veh and veh ~= 0 then DeleteEntity(veh) end
    end
    missions[source] = nil
end)

RegisterNetEvent('saa:air:cancel', function()
    local src = source
    local m = missions[src]
    if not m then return end
    if m.cargoNet then
        local ent = NetworkGetEntityFromNetworkId(m.cargoNet)
        if ent and ent ~= 0 then DeleteEntity(ent) end
    end
    if m.heliNet then
        local veh = NetworkGetEntityFromNetworkId(m.heliNet)
        if veh and veh ~= 0 then DeleteEntity(veh) end
    end
    m.state = 'done'
    m.heliNet = nil
    m.cargoNet = nil
    TriggerClientEvent('saa:air:finished', src, false)
end)
