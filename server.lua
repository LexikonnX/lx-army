local ESX = exports['es_extended']:getSharedObject()
local lastPager = {}

local weaponBanEnabled = Config.WeaponBanDefault

local dutyOn = {}
local dutyPos = {}
local dutyName = {}

local function getX(src)
    return ESX.GetPlayerFromId(src)
end

local function isArmy(src)
    local x = getX(src)
    if not x or not x.job then return false end
    return x.job.name == Config.Job
end

local function fmtName(x)
    local n = (x.getName and x.getName()) or GetPlayerName(x.source) or ('ID '..tostring(x.source))
    return n
end

local function setName(src)
    local x = getX(src)
    if x then dutyName[src] = fmtName(x) end
end

local function broadcast()
    local pack = {}
    for id,pos in pairs(dutyPos) do
        if dutyOn[id] then
            pack[#pack+1] = {id=id, x=pos.x, y=pos.y, z=pos.z, name=dutyName[id] or ('ID '..id)}
        end
    end
    for id,_ in pairs(dutyOn) do
        TriggerClientEvent('lx-army:duty:positions', id, pack)
    end
end

local function canSend(src)
    local x = getX(src)
    if not x or not x.job then return false end
    if x.job.name ~= Config.Job then return false end
    local grade = tonumber(x.job.grade or 0) or 0
    return grade >= (Config.MinGrade or 0)
end

local function canToggle(src)
    local x = getX(src)
    if not x or not x.job then return false end
    if x.job.name ~= Config.Job then return false end
    local grade = tonumber(x.job.grade or 0) or 0
    return grade >= (Config.WeaponToggleGrade or 0)
end

local function forEachJob(job, cb)
    if ESX.GetExtendedPlayers then
        for _, xp in pairs(ESX.GetExtendedPlayers()) do
            if xp.job and xp.job.name == job then cb(xp) end
        end
    else
        for _, id in ipairs(ESX.GetPlayers()) do
            local xp = ESX.GetPlayerFromId(id)
            if xp and xp.job and xp.job.name == job then cb(xp) end
        end
    end
end

RegisterCommand('pager', function(src, args)
    if not canSend(src) then return end
    local now = os.time()
    if lastPager[src] and now - lastPager[src] < Config.PagerCooldown then
        TriggerClientEvent('esx:showNotification', src, 'Pager cooldown')
        return
    end
    local priority = tostring(args[1] or 'green'):lower()
    if priority ~= 'green' and priority ~= 'yellow' and priority ~= 'red' then
        priority = 'green'
    end
    table.remove(args, 1)
    local msg = table.concat(args, ' ')
    if #msg < 1 or #msg > Config.MessageMax then
        TriggerClientEvent('esx:showNotification', src, 'Invalid message')
        return
    end
    lastPager[src] = now
    forEachJob(Config.Job, function(xp)
        TriggerClientEvent('lx-army:pager:show', xp.source, priority, msg)
    end)
end)

RegisterCommand('pg', function(src, args)
    if not canSend(src) then return end
    local now = os.time()
    if lastPager[src] and now - lastPager[src] < Config.PagerCooldown then
        TriggerClientEvent('esx:showNotification', src, 'Pager cooldown')
        return
    end
    local priority = 'green'
    local msg = table.concat(args, ' ')
    if #msg < 1 or #msg > Config.MessageMax then
        TriggerClientEvent('esx:showNotification', src, 'Invalid message')
        return
    end
    lastPager[src] = now
    forEachJob(Config.Job, function(xp)
        TriggerClientEvent('lx-army:pager:show', xp.source, priority, msg)
    end)
end)

RegisterCommand('py', function(src, args)
    if not canSend(src) then return end
    local now = os.time()
    if lastPager[src] and now - lastPager[src] < Config.PagerCooldown then
        TriggerClientEvent('esx:showNotification', src, 'Pager cooldown')
        return
    end
    local priority = 'yellow'
    local msg = table.concat(args, ' ')
    if #msg < 1 or #msg > Config.MessageMax then
        TriggerClientEvent('esx:showNotification', src, 'Invalid message')
        return
    end
    lastPager[src] = now
    forEachJob(Config.Job, function(xp)
        TriggerClientEvent('lx-army:pager:show', xp.source, priority, msg)
    end)
end)

RegisterCommand('pr', function(src, args)
    if not canSend(src) then return end
    local now = os.time()
    if lastPager[src] and now - lastPager[src] < Config.PagerCooldown then
        TriggerClientEvent('esx:showNotification', src, 'Pager cooldown')
        return
    end
    local priority = 'red'
    local msg = table.concat(args, ' ')
    if #msg < 1 or #msg > Config.MessageMax then
        TriggerClientEvent('esx:showNotification', src, 'Invalid message')
        return
    end
    lastPager[src] = now
    forEachJob(Config.Job, function(xp)
        TriggerClientEvent('lx-army:pager:show', xp.source, priority, msg)
    end)
end)

RegisterCommand('armguns', function(src)
    if not canToggle(src) then
        TriggerClientEvent('esx:showNotification', src, 'Nemáš oprávnění')
        return
    end
    weaponBanEnabled = not weaponBanEnabled
    TriggerClientEvent('lx-army:wepban:set', -1, weaponBanEnabled)
    TriggerClientEvent('esx:showNotification', src, weaponBanEnabled and 'Zákaz zbraní AKTIVNÍ' or 'Zákaz zbraní VYPNUTÝ')
end)

RegisterCommand('armgunsstate', function(src)
    TriggerClientEvent('esx:showNotification', src, weaponBanEnabled and 'Stav: AKTIVNÍ' or 'Stav: VYPNUTÝ')
end)

RegisterNetEvent('lx-army:wepban:request', function()
    TriggerClientEvent('lx-army:wepban:set', source, weaponBanEnabled)
end)

AddEventHandler('onResourceStart', function(res)
    if res ~= GetCurrentResourceName() then return end
    Wait(500)
    TriggerClientEvent('lx-army:wepban:set', -1, weaponBanEnabled)
end)

RegisterCommand('Aduty', function(src)
    TriggerEvent('lx-army:duty:toggle', src)
end)

RegisterNetEvent('lx-army:duty:toggle', function(playerSrc)
    local src = playerSrc or source
    if not isArmy(src) then return end
    if not dutyOn[src] then setName(src) end
    dutyOn[src] = not dutyOn[src]
    if not dutyOn[src] then dutyPos[src] = nil end
    TriggerClientEvent('lx-army:duty:state', src, dutyOn[src] == true)
    TriggerClientEvent('esx:showNotification', src, dutyOn[src] and 'Jsi ve službě' or 'Jsi mimo službu')
    broadcast()
end)

RegisterNetEvent('lx-army:duty:pos', function(x,y,z)
    local src = source
    if not dutyOn[src] then return end
    dutyPos[src] = vec3(x,y,z)
    if not dutyName[src] then setName(src) end
    broadcast()
end)

RegisterNetEvent('lx-army:duty:request', function()
    local src = source
    if not isArmy(src) then
        TriggerClientEvent('lx-army:duty:state', src, false)
        return
    end
    setName(src)
    TriggerClientEvent('lx-army:duty:state', src, dutyOn[src] == true)
    broadcast()
end)

AddEventHandler('playerDropped', function()
    local src = source
    dutyOn[src] = nil
    dutyPos[src] = nil
    dutyName[src] = nil
    broadcast()
end)

RegisterNetEvent('lx-army:recruit:send', function(payload)
    local src = source
    if not Config.Recruit or not Config.Recruit.webhook or Config.Recruit.webhook == '' then
        TriggerClientEvent('esx:showNotification', src, 'Webhook není nastaven')
        return
    end

    local function trim(s)
        if type(s) ~= 'string' then return '' end
        return s:gsub('^%s+', ''):gsub('%s+$', '')
    end

    local x = ESX.GetPlayerFromId(src)
    local pname = (x and (x.getName and x.getName() or GetPlayerName(src))) or ('ID '..tostring(src))

    local items, missing = {}, {}
    if type(payload) == 'table' then
        for _, f in ipairs(Config.Recruit.fields or {}) do
            local key = f.key
            local raw = payload[key]
            local v = trim(tostring(raw or ''))
            if v == '' then
                missing[#missing+1] = (f.label or key)
            end
            if #v > 1024 then v = v:sub(1, 1021)..'...' end
            items[#items+1] = { name = (f.label or key), value = v, inline = false }
        end
    end

    if #items == 0 then
        TriggerClientEvent('esx:showNotification', src, 'Formulář je prázdný')
        return
    end
    if #missing > 0 then
        TriggerClientEvent('esx:showNotification', src, 'Vyplň všechna pole')
        return
    end

    local embed = {
        title = 'Nová přihláška do armády',
        color = 3048322,
        fields = items,
        footer = { text = pname },
        timestamp = os.date('!%Y-%m-%dT%H:%M:%S.000Z')
    }

    local body = json.encode({
        content = nil,
        embeds = { embed },
        username = 'Army Recruitment',
        avatar_url = Config.Recruit.avatar_url or ''
    })

    PerformHttpRequest(Config.Recruit.webhook, function(code, res)
        local ok = (code and code >= 200 and code < 300)
        if ok then
            print('[SAA Recruit] Webhook OK ('..tostring(code)..')')
            TriggerClientEvent('esx:showNotification', src, 'Přihláška odeslána, nyní vyčkej na kontaktování')
        else
            print('[SAA Recruit] Webhook FAIL ('..tostring(code or '?')..'): '..tostring(res or ''))
            TriggerClientEvent('esx:showNotification', src, 'Odeslání selhalo ('..tostring(code or '?')..')')
        end
    end, 'POST', body, { ['Content-Type'] = 'application/json' })
end)

RegisterNetEvent('lx-army:cac:requestShow')
AddEventHandler('lx-army:cac:requestShow', function(targetId, name, rank)
    TriggerClientEvent('lx-army:cac:openNui', targetId, name, rank)
end)

local spawnCounts = {}
local playerSpawns = {}
local modelMax = {}

local function buildMaxMap()
    for _, v in ipairs(Config.Helis or {}) do modelMax[tostring(v.model)] = tonumber(v.max or 0) end
    for _, v in ipairs(Config.Planes or {}) do modelMax[tostring(v.model)] = tonumber(v.max or 0) end
    for _, v in ipairs(Config.Boats or {}) do modelMax[tostring(v.model)] = tonumber(v.max or 0) end
end

AddEventHandler('onResourceStart', function(res)
    if res ~= GetCurrentResourceName() then return end
    buildMaxMap()
end)

RegisterNetEvent('lx-army:spawn:request', function(kind, model)
    local src = source
    if not isArmy(src) then return end
    local mdl = tostring(model)
    local max = tonumber(modelMax[mdl] or 0)
    local cur = tonumber(spawnCounts[mdl] or 0)
    if max > 0 and cur >= max then
        TriggerClientEvent('esx:showNotification', src, 'Limit pro toto vozidlo je vyčerpán', 'error')
        return
    end
    spawnCounts[mdl] = cur + 1
    playerSpawns[src] = playerSpawns[src] or {}
    table.insert(playerSpawns[src], { kind = kind, model = mdl })
    TriggerClientEvent('lx-army:spawn:approved', src, kind, mdl)
end)

RegisterNetEvent('lx-army:spawn:despawn', function(kind, model)
    local src = source
    local mdl = tostring(model)
    if spawnCounts[mdl] and spawnCounts[mdl] > 0 then
        spawnCounts[mdl] = spawnCounts[mdl] - 1
    end
    if playerSpawns[src] then
        for i = #playerSpawns[src], 1, -1 do
            local it = playerSpawns[src][i]
            if it and it.model == mdl and it.kind == kind then
                table.remove(playerSpawns[src], i)
                break
            end
        end
        if #playerSpawns[src] == 0 then playerSpawns[src] = nil end
    end
end)

AddEventHandler('playerDropped', function()
    local src = source
    local list = playerSpawns[src]
    if list then
        for _, it in ipairs(list) do
            local mdl = it.model
            if spawnCounts[mdl] and spawnCounts[mdl] > 0 then
                spawnCounts[mdl] = spawnCounts[mdl] - 1
            end
        end
        playerSpawns[src] = nil
    end
end)
