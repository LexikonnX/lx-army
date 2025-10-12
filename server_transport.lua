local ESX = exports['es_extended']:getSharedObject()

local missions = {}

local function isArmy(x)
    return x and x.job and x.job.name == (Config.Job or 'army')
end

local function pickRandomDestination()
    local list = Config.Transport.Destinations or {}
    if #list == 0 then return nil end
    math.randomseed(GetGameTimer())
    local idx = math.random(1, #list)
    return list[idx]
end

local function pickMode()
    local w = Config.Transport.ModeChances or { boxes = 40, tanker_drop = 30, tanker_pick = 30 }
    local b, d, p = tonumber(w.boxes) or 40, tonumber(w.tanker_drop) or 30, tonumber(w.tanker_pick) or 30
    local total = math.max(1, b + d + p)
    local r = math.random(1, total)
    if r <= b then return 'boxes' end
    if r <= b + d then return 'tanker_drop' end
    return 'tanker_pick'
end


CreateThread(function()
    math.randomseed(os.time() + math.floor(os.clock() * 1000000))
    for i = 1, 3 do math.random() end
end)

RegisterNetEvent('saa:transport:start', function()
    local src = source
    local x = ESX.GetPlayerFromId(src)
    if not isArmy(x) then return end
    if missions[src] and missions[src].state and missions[src].state ~= 'done' then return end
    local dest = pickRandomDestination()
    if not dest then return end
    local mode = pickMode()
    local truck = Config.Transport.BoxModeTruck
    local withTrailer = false
    if mode ~= 'boxes' then truck = Config.Transport.TankerTruck end
    if mode == 'tanker_drop' then withTrailer = true end
    missions[src] = {
        state = 'enroute',
        dest = dest.id,
        mode = mode,
        truck = truck,
        withTrailer = withTrailer,
        trailerNet = nil,
        vehNet = nil,
        total = Config.Transport.PackageCount or 10,
        left  = Config.Transport.PackageCount or 10,
        reward = dest.reward or 0
    }
    TriggerClientEvent('saa:transport:started', src, {
        dest = dest.id,
        mode = mode,
        truck = truck,
        withTrailer = withTrailer
    })
end)

RegisterNetEvent('saa:transport:setVeh', function(netId)
    local src = source
    local m = missions[src]
    if not m or (m.state ~= 'enroute' and m.state ~= 'carrying') then return end
    m.vehNet = netId
end)

RegisterNetEvent('saa:transport:setTrailer', function(netId)
    local src = source
    local m = missions[src]
    if not m then return end
    m.trailerNet = netId
end)

RegisterNetEvent('saa:transport:setCarrying', function(flag)
    local src = source
    local m = missions[src]
    if not m or (m.state ~= 'enroute' and m.state ~= 'carrying') then return end
    m.carrying = flag and true or false
    if flag then m.state = 'carrying' end
end)

RegisterNetEvent('saa:transport:pkgleft', function()
end)

RegisterNetEvent('saa:transport:delivered', function()
    local src = source
    local m = missions[src]
    if not m or not m.carrying then return end
    m.carrying = false
    if m.left and m.left > 0 then m.left = m.left - 1 end
    if m.left > 0 then
        TriggerClientEvent('saa:transport:pkgleft', src, m.left, m.total)
    else
        m.state = 'delivered'
        TriggerClientEvent('saa:transport:delivered_ack', src)
    end
end)

RegisterNetEvent('saa:transport:tankerDetached', function()
    local src = source
    local m = missions[src]
    if not m or m.mode ~= 'tanker_drop' then return end
    m.state = 'delivered'
    if m.trailerNet then
        local ent = NetworkGetEntityFromNetworkId(m.trailerNet)
        if ent and ent ~= 0 then DeleteEntity(ent) end
        m.trailerNet = nil
    end
    TriggerClientEvent('saa:transport:tanker_ok', src)
end)

RegisterNetEvent('saa:transport:tankerAttached', function()
    local src = source
    local m = missions[src]
    if not m or m.mode ~= 'tanker_pick' then return end
    m.state = 'delivered'
    TriggerClientEvent('saa:transport:tanker_ok', src)
end)

local function payReward(src, amount, account)
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then return end
    account = account or 'bank'

    if account == 'bank' then
        local ok = pcall(function() xPlayer.addAccountMoney('bank', amount) end)
        if not ok then
            if GetResourceState('ox_inventory') == 'started' then
                local ok2 = pcall(function() exports.ox_inventory:AddItem(src, 'money', amount) end)
                if not ok2 then xPlayer.addMoney(amount) end
            else
                xPlayer.addMoney(amount)
            end
        end
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

local function _returnPos()
    local t = Config.Transport or {}
    local s = t.Start or {}
    return t.vehicleReturn or s.vehicleReturn or s.startZone or Config.Base
end

local function _returnRadius()
    local t = Config.Transport or {}
    local s = t.Start or {}
    return t.returnRadius or s.returnRadius or ((s.startRadius or 2.5) + 3.0)
end

RegisterNetEvent('saa:transport:return', function()
    local src = source
    local m = missions[src]
    if not m or m.state ~= 'delivered' then return end
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return end
    local p = GetEntityCoords(ped)
    local rz = _returnPos()
    local rr = _returnRadius()
    local dx, dy, dz = p.x - rz.x, p.y - rz.y, p.z - rz.z
    if (dx*dx + dy*dy + dz*dz) > (rr*rr) then return end
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end
    payReward(src, m.reward or 0, Config.Transport.PayAccount or 'bank')
    if m.trailerNet then
        local tr = NetworkGetEntityFromNetworkId(m.trailerNet)
        if tr and tr ~= 0 then DeleteEntity(tr) end
    end
    if m.vehNet then
        local ent = NetworkGetEntityFromNetworkId(m.vehNet)
        if ent and ent ~= 0 then DeleteEntity(ent) end
    end
    m.state = 'done'
    m.carrying = false
    m.vehNet = nil
    m.trailerNet = nil
    TriggerClientEvent('saa:transport:finished', src, true)
end)

AddEventHandler('playerDropped', function()
    missions[source] = nil
end)

RegisterNetEvent('saa:transport:cancel', function()
    local src = source
    local m = missions[src]
    if not m then return end
    if m.trailerNet then
        local tr = NetworkGetEntityFromNetworkId(m.trailerNet)
        if tr and tr ~= 0 then DeleteEntity(tr) end
    end
    if m.vehNet then
        local ent = NetworkGetEntityFromNetworkId(m.vehNet)
        if ent and ent ~= 0 then DeleteEntity(ent) end
    end
    m.state = 'done'
    m.carrying = false
    m.vehNet = nil
    m.trailerNet = nil
    TriggerClientEvent('saa:transport:finished', src, false)
end)
