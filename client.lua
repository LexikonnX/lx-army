local ESX = exports['es_extended']:getSharedObject()
local PlayerJob = nil
local isOnDuty = false
local dutyBlips = {}
local recruitPeds = {}

local weaponBanEnabled = Config.WeaponBanDefault

local pullupDict = 'PROP_HUMAN_MUSCLE_CHIN_UPS'
local pullupActive = false

local pullupSpots = {
    vector4(-1963.8796, 3341.6299, 32.9602, 54.5494),
    vector4(-1967.0624, 3336.3711, 32.9603, 58.7777),
    vector4(-1970.4866, 3330.2148, 32.9603, 63.9957)
}

local function getNearbySpot(radius)
    local ped = PlayerPedId()
    local pos = GetEntityCoords(ped)
    for _, s in ipairs(pullupSpots) do
        if #(pos - vector3(s.x, s.y, s.z)) < radius then
            return s
        end
    end
    return nil
end

local function goToAndAlign(ped, spot)
    TaskGoToCoordAnyMeans(ped, spot.x, spot.y, spot.z, 1.0, 0, 0, 786603, 0.0)
    local timeout = GetGameTimer() + 10000
    while #(GetEntityCoords(ped) - vector3(spot.x, spot.y, spot.z)) > 0.65 and GetGameTimer() < timeout do
        Wait(10)
    end
    ClearPedTasks(ped)
    TaskAchieveHeading(ped, spot.w, 1000)
    Wait(600)
end

CreateThread(function()
    while true do
        Wait(0)
        local ped = PlayerPedId()

        if not pullupActive then
            local spot = getNearbySpot(1.6)
            if spot then
                BeginTextCommandDisplayHelp('STRING')
                AddTextComponentSubstringPlayerName('~INPUT_CONTEXT~ pro ~g~prítahy~s~')
                EndTextCommandDisplayHelp(0, false, true, -1)

                if IsControlJustPressed(0, 38) then
                    local ped = PlayerPedId()
                    ClearPedTasks(ped)
                    goToAndAlign(ped, spot)
                    TaskStartScenarioAtPosition(ped, pullupDict, spot.x, spot.y, spot.z, spot.w, 0, true, true)
                    pullupActive = true
                end
            end
        else
            BeginTextCommandDisplayHelp('STRING')
            AddTextComponentSubstringPlayerName('Zrušit ~INPUT_CELLPHONE_CANCEL~')
            EndTextCommandDisplayHelp(0, false, true, -1)

            if IsControlJustPressed(0, 177) then
                ClearPedTasks(ped)
                pullupActive = false
            end

            if not IsPedUsingAnyScenario(ped) then
                pullupActive = false
            end
        end
    end
end)

RegisterNetEvent('lx-army:wepban:set', function(state)
    weaponBanEnabled = state
end)

CreateThread(function()
    TriggerServerEvent('lx-army:wepban:request')
end)

local function isAllowedHeliModel(model)
    for _, v in pairs(Config.Helis) do
        if model == GetHashKey(v.model) then return true end
    end
    return false
end

local function isAllowedPlaneModel(model)
    for _, v in pairs(Config.Planes) do
        if model == GetHashKey(v.model) then return true end
    end
    return false
end

local function isAllowedBoatModel(model)
    if type(Config.Boats) ~= "table" then return model == GetHashKey('predator') end
    for _, v in pairs(Config.Boats) do
        if model == GetHashKey(v.model) then return true end
    end
    return false
end

local function nameFromHash(kind, hash)
    if kind == 'boat' then
        if type(Config.Boats) == 'table' then
            for _, v in ipairs(Config.Boats) do
                if GetHashKey(v.model) == hash then return v.model end
            end
        else
            if GetHashKey('predator') == hash then return 'predator' end
        end
    elseif kind == 'heli' then
        for _, v in ipairs(Config.Helis or {}) do
            if GetHashKey(v.model) == hash then return v.model end
        end
    elseif kind == 'plane' then
        for _, v in ipairs(Config.Planes or {}) do
            if GetHashKey(v.model) == hash then return v.model end
        end
    end
    return nil
end

local function GetClosestPlayer(radius)
    local players = GetActivePlayers()
    local myPed = PlayerPedId()
    local myCoords = GetEntityCoords(myPed)
    local closestId = nil
    local closestDist = radius + 0.01
    for _, p in ipairs(players) do
        if p ~= PlayerId() then
            local ped = GetPlayerPed(p)
            local coords = GetEntityCoords(ped)
            local d = #(myCoords - coords)
            if d < closestDist then
                closestDist = d
                closestId = GetPlayerServerId(p)
            end
        end
    end
    return closestId
end

local function getLocalCharInfo()
    local pd = ESX.GetPlayerData()
    local name = pd.name or GetPlayerName(PlayerId())
    local rank = (pd.job and pd.job.grade_label) or ''
    return name, rank
end

local function startBeeps(priority)
    local t = 2
    local gap = 320
    local name = 'CONFIRM_BEEP'
    local set = 'HUD_MINI_GAME_SOUNDSET'
    if priority == 'yellow' then t = 3 end
    if priority == 'red' then t = 4 name = 'TIMER_STOP' gap = 260 end
    CreateThread(function()
        for i = 1, t do
            PlaySoundFrontend(-1, name, set, true)
            Wait(gap)
        end
    end)
end

local function setBlipName(bl, name)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(name)
    EndTextCommandSetBlipName(bl)
end

local function ensureBlip(id, data)
    local bl = dutyBlips[id]
    if not bl or not DoesBlipExist(bl) then
        bl = AddBlipForCoord(data.x, data.y, data.z)
        SetBlipSprite(bl, 58)
        SetBlipColour(bl, 2)
        SetBlipScale(bl, 0.85)
        SetBlipAsShortRange(bl, false)
        setBlipName(bl, 'Soldier')
        dutyBlips[id] = bl
    else
        SetBlipCoords(bl, data.x, data.y, data.z)
    end
end

local function clearBlips()
    for id,bl in pairs(dutyBlips) do
        if DoesBlipExist(bl) then RemoveBlip(bl) end
    end
    dutyBlips = {}
end

local heliBlips, planeBlips, boatBlips = {}, {}, {}

local function clearSpawnBlips()
    for _,b in ipairs(heliBlips) do if DoesBlipExist(b) then RemoveBlip(b) end end
    for _,b in ipairs(planeBlips) do if DoesBlipExist(b) then RemoveBlip(b) end end
    for _,b in ipairs(boatBlips) do if DoesBlipExist(b) then RemoveBlip(b) end end
    heliBlips = {}
    planeBlips = {}
    boatBlips = {}
end

local function DrawText3D(x, y, z, text)
    SetDrawOrigin(x, y, z, 0)
    SetTextScale(0.35, 0.35)
    SetTextFont(4)
    SetTextProportional(1)
    SetTextColour(255, 255, 255, 215)
    SetTextEntry("STRING")
    SetTextCentre(1)
    AddTextComponentString(text)
    DrawText(0.0, 0.0)
    ClearDrawOrigin()
end

local function createBlips()
    local pd = ESX.GetPlayerData()
    PlayerJob = pd and pd.job and pd.job.name or nil
    if PlayerJob ~= Config.Job then return end
    clearSpawnBlips()
    if type(Config.SpawnPoint) == "table" and Config.SpawnGarageHeli then
        for _, sp in ipairs(Config.SpawnPoint) do
            local b = AddBlipForCoord(sp.x, sp.y, sp.z)
            SetBlipSprite(b, 43)
            SetBlipDisplay(b, 4)
            SetBlipScale(b, 0.9)
            SetBlipColour(b, 2)
            SetBlipAsShortRange(b, true)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentString('Army Helipad')
            EndTextCommandSetBlipName(b)
            table.insert(heliBlips, b)
        end
    end
    if type(Config.SpawnPointPlane) == "table" and Config.SpawnGaragePlane then
        for _, sp in ipairs(Config.SpawnPointPlane) do
            local b = AddBlipForCoord(sp.x, sp.y, sp.z)
            SetBlipSprite(b, 16)
            SetBlipDisplay(b, 4)
            SetBlipScale(b, 0.9)
            SetBlipColour(b, 2)
            SetBlipAsShortRange(b, true)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentString('Army Hangar')
            EndTextCommandSetBlipName(b)
            table.insert(planeBlips, b)
        end
    end
    if type(Config.SpawnGarageBoat) == "table" and Config.SpawnGarageBoat.point then
        local p = Config.SpawnGarageBoat.point
        local b = AddBlipForCoord(p.x, p.y, p.z)
        SetBlipSprite(b, 427)
        SetBlipDisplay(b, 4)
        SetBlipScale(b, 0.9)
        SetBlipColour(b, 2)
        SetBlipAsShortRange(b, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentString('Army Dock')
        EndTextCommandSetBlipName(b)
        table.insert(boatBlips, b)
    end
end

CreateThread(function()
    while true do
        local pd = ESX.GetPlayerData()
        if pd and pd.job and pd.job.name then
            PlayerJob = pd.job.name
            createBlips()
            break
        end
        Wait(200)
    end
end)

RegisterNetEvent('lx-army:pager:show', function(priority, msg)
    startBeeps(priority or 'green')
    SendNUIMessage({
        action = 'showPager',
        priority = priority,
        message = msg,
        duration = Config.PagerDuration
    })
    SetNuiFocus(false, false)
end)

local modelHashes = {}
for _, m in ipairs(Config.blacklistModels) do
  modelHashes[string.lower(m)] = GetHashKey(m)
end

local noWeapons = false

CreateThread(function()
  while true do
    Wait(1000)
    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) then
      local veh = GetVehiclePedIsIn(ped, false)
      local model = GetEntityModel(veh)
      local isBlack = false
      for _, h in pairs(modelHashes) do
        if model == h then isBlack = true break end
      end
      if isBlack and weaponBanEnabled then
        noWeapons = true
      else
        noWeapons = false
      end
    else
      noWeapons = false
    end
  end
end)

CreateThread(function()
  while true do
    Wait(0)
    if noWeapons then
      local ped = PlayerPedId()
      if GetSelectedPedWeapon(ped) ~= `WEAPON_UNARMED` then
        SetCurrentPedWeapon(ped, `WEAPON_UNARMED`, true)
      end
      DisableControlAction(0, 24, true)
      DisableControlAction(0, 25, true)
      DisableControlAction(0, 68, true)
      DisableControlAction(0, 69, true)
      DisableControlAction(0, 70, true)
      DisableControlAction(0, 91, true)
      DisableControlAction(0, 92, true)
      DisableControlAction(0, 114, true)
    else
      Wait(250)
    end
  end
end)

local showing = false

local function nearestV4(list, from)
    local nearest, nd = nil, 1e9
    for _, sp in ipairs(list) do
        local d = #(from - vector3(sp.x, sp.y, sp.z))
        if d < nd then
            nd = d
            nearest = sp
        end
    end
    return nearest, nd
end

CreateThread(function()
    while Config.SpawnGarageHeli or Config.SpawnGaragePlane do
        Wait(0)
        local ped = PlayerPedId()
        local coords = GetEntityCoords(ped)
        if Config.SpawnGarageHeli then
            if type(Config.SpawnPoint) == "table" and #Config.SpawnPoint > 0 then
                for _, sp in ipairs(Config.SpawnPoint) do
                    if #(coords - vector3(sp.x, sp.y, sp.z)) < 10.0 then
                        DrawMarker(1, sp.x, sp.y, sp.z - 1.0, 0, 0, 0, 0, 0, 0, 1.0,1.0,0.5,0,200,0,150, false, false, 2, nil, nil, false)
                        if not showing then
                            DrawText3D(sp.x, sp.y, sp.z, "~w~[~y~E~w~] ~g~Heliport")
                        end
                        if IsControlJustReleased(0, 38) then
                            TriggerEvent('lx-army:heli:menu')
                        end
                    end
                end
            end
        end
        if Config.SpawnGaragePlane then
            if type(Config.SpawnPointPlane) == "table" and #Config.SpawnPointPlane > 0 then
                for _, sp in ipairs(Config.SpawnPointPlane) do
                    if #(coords - vector3(sp.x, sp.y, sp.z)) < 10.0 then
                        DrawMarker(1, sp.x, sp.y, sp.z - 1.0, 0, 0, 0, 0, 0, 0, 1.0,1.0,0.5,0,200,0,150, false, false, 2, nil, nil, false)
                        if not showing then
                            DrawText3D(sp.x, sp.y, sp.z, "~w~[~y~E~w~] ~g~Hangar")
                        end
                        if IsControlJustReleased(0, 38) then
                            TriggerEvent('lx-army:plane:menu')
                        end
                    end
                end
            end
        end
        if Config.SpawnGarageBoat and Config.SpawnGarageBoat.point then
            local sp = Config.SpawnGarageBoat.point
            if #(coords - vector3(sp.x, sp.y, sp.z)) < 10.0 then
                DrawMarker(1, sp.x, sp.y, sp.z - 1.0, 0, 0, 0, 0, 0, 0, 1.0,1.0,0.5,0,200,0,150, false, false, 2, nil, nil, false)
                if not showing then
                    DrawText3D(sp.x, sp.y, sp.z, "~w~[~y~E~w~] ~g~Dock")
                end
                if IsControlJustReleased(0, 38) then
                    TriggerEvent('lx-army:boat:menu')
                end
            end
        end
    end
end)

RegisterNetEvent('lx-army:heli:menu', function()
    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) then
        local veh = GetVehiclePedIsIn(ped, false)
        local model = GetEntityModel(veh)
        if isAllowedHeliModel(model) then
            local name = nameFromHash('heli', model)
            if DoesEntityExist(veh) then DeleteVehicle(veh) end
            TriggerServerEvent('lx-army:spawn:despawn', 'heli', name or model)
            TriggerEvent('esx:showNotification', 'Vrtulník zaparkován')
            return
        end
    end
    local options = {}
    for _, v in pairs(Config.Helis) do
        options[#options+1] = { title = v.label, event = 'lx-army:heli:spawn', args = { model = v.model } }
    end
    lib.registerContext({ id = 'saa_heli_menu', title = 'Army Helipad', options = options })
    lib.showContext('saa_heli_menu')
end)

RegisterNetEvent('lx-army:plane:menu', function()
    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) then
        local veh = GetVehiclePedIsIn(ped, false)
        local model = GetEntityModel(veh)
        if isAllowedPlaneModel(model) then
            local name = nameFromHash('plane', model)
            if DoesEntityExist(veh) then DeleteVehicle(veh) end
            TriggerServerEvent('lx-army:spawn:despawn', 'plane', name or model)
            TriggerEvent('esx:showNotification', 'Letadlo zaparkováno')
            return
        end
    end
    local options = {}
    for _, v in pairs(Config.Planes) do
        options[#options+1] = { title = v.label, event = 'lx-army:plane:spawn', args = { model = v.model } }
    end
    lib.registerContext({ id = 'saa_plane_menu', title = 'Army Hangar', options = options })
    lib.showContext('saa_plane_menu')
end)

RegisterNetEvent('lx-army:heli:spawn', function(data)
    local model = data.model
    TriggerServerEvent('lx-army:spawn:request', 'heli', model)
end)

RegisterNetEvent('lx-army:plane:spawn', function(data)
    local model = data.model
    TriggerServerEvent('lx-army:spawn:request', 'plane', model)
end)

RegisterNetEvent('lx-army:boat:spawn', function(data)
    local model = data.model or 'predator'
    TriggerServerEvent('lx-army:spawn:request', 'boat', model)
end)

RegisterNetEvent('lx-army:spawn:approved', function(kind, model)
    local mdl = model
    if type(mdl) == 'string' then mdl = GetHashKey(mdl) end
    RequestModel(mdl)
    while not HasModelLoaded(mdl) do Wait(0) end

    local ped = PlayerPedId()
    local veh, sp

    if kind == 'heli' then
        sp = nearestV4(Config.SpawnPoint, GetEntityCoords(ped))
        if not sp then return end
        veh = CreateVehicle(mdl, sp.x, sp.y, sp.z, sp.w, true, true)
    elseif kind == 'plane' then
        sp = nearestV4(Config.SpawnPointPlane, GetEntityCoords(ped))
        if not sp then return end
        veh = CreateVehicle(mdl, sp.x, sp.y, sp.z, sp.w, true, true)
    elseif kind == 'boat' then
        sp = Config.SpawnGarageBoat and Config.SpawnGarageBoat.spawn
        if not sp then return end
        veh = CreateVehicle(mdl, sp.x, sp.y, sp.z, sp.w, true, true)
    else
        return
    end

    SetVehicleEngineOn(veh, true, true, false)
    TaskWarpPedIntoVehicle(ped, veh, -1)
    SetEntityAsMissionEntity(veh, true, true)
    SetVehicleDirtLevel(veh, 0.0)
end)

RegisterNetEvent('lx-army:boat:menu', function()
    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) then
        local veh = GetVehiclePedIsIn(ped, false)
        local model = GetEntityModel(veh)
        if isAllowedBoatModel(model) then
            local name = nameFromHash('boat', model)
            if DoesEntityExist(veh) then DeleteVehicle(veh) end
            TriggerServerEvent('lx-army:spawn:despawn', 'boat', name or model)
            TriggerEvent('esx:showNotification', 'Člun zaparkován')
            return
        end
    end
    if type(Config.Boats) == "table" and #Config.Boats > 0 then
        local options = {}
        for _, v in pairs(Config.Boats) do
            options[#options+1] = { title = v.label, event = 'lx-army:boat:spawn', args = { model = v.model } }
        end
        lib.registerContext({ id = 'saa_boat_menu', title = 'Army Dock', options = options })
        lib.showContext('saa_boat_menu')
    else
        TriggerEvent('lx-army:boat:spawn', { model = 'predator' })
    end
end)

RegisterNetEvent('lx-army:boat:store', function()
    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) then
        local veh = GetVehiclePedIsIn(ped, false)
        local model = GetEntityModel(veh)
        local allowed = isAllowedBoatModel(model)
        if allowed then
            local name = nameFromHash('boat', model)
            if DoesEntityExist(veh) then DeleteVehicle(veh) end
            TriggerServerEvent('lx-army:spawn:despawn', 'boat', name or model)
            TriggerEvent('esx:showNotification', "Člun zaparkován")
        else
            TriggerEvent('esx:showNotification', "Tento člun nelze zaparkovat")
        end
    else
        TriggerEvent('esx:showNotification', "Musíš sedět v člunu")
    end
end)

RegisterNetEvent('lx-army:heli:store', function()
    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) then
        local veh = GetVehiclePedIsIn(ped, false)
        local model = GetEntityModel(veh)
        local allowed = false
        for _, v in pairs(Config.Helis) do
            if model == GetHashKey(v.model) then allowed = true break end
        end
        if allowed then
            local name = nameFromHash('heli', model)
            if DoesEntityExist(veh) then DeleteVehicle(veh) end
            TriggerServerEvent('lx-army:spawn:despawn', 'heli', name or model)
            TriggerEvent('esx:showNotification', "Vrtulník zaparkován")
        else
            TriggerEvent('esx:showNotification', "Tento vrtulník nelze zaparkovat")
        end
    else
        TriggerEvent('esx:showNotification', "Musíš sedět ve vrtulníku")
    end
end)

RegisterNetEvent('lx-army:plane:store', function()
    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) then
        local veh = GetVehiclePedIsIn(ped, false)
        local model = GetEntityModel(veh)
        local allowed = false
        for _, v in pairs(Config.Planes) do
            if model == GetHashKey(v.model) then allowed = true break end
        end
        if allowed then
            local name = nameFromHash('plane', model)
            if DoesEntityExist(veh) then DeleteVehicle(veh) end
            TriggerServerEvent('lx-army:spawn:despawn', 'plane', name or model)
            TriggerEvent('esx:showNotification', "Letadlo zaparkováno")
        else
            TriggerEvent('esx:showNotification', "Toto letadlo nelze zaparkovat")
        end
    else
        TriggerEvent('esx:showNotification', "Musíš sedět v letadle")
    end
end)


CreateThread(function()
    Wait(500)
    TriggerEvent('chat:addSuggestion', '/pager', 'SAA Pager', {
        { name = 'priority', help = 'green | yellow | red' },
        { name = 'message', help = 'text' }
    })
    TriggerEvent('chat:addSuggestion', '/pg', 'Quick SAA Pager (Green)', {
        { name = 'message', help = 'text' }
    })
    TriggerEvent('chat:addSuggestion', '/py', 'Quick SAA Pager (Yellow)', {
        { name = 'message', help = 'text' }
    })
    TriggerEvent('chat:addSuggestion', '/pr', 'Quick SAA Pager (Red)', {
        { name = 'message', help = 'text' }
    })
end)

RegisterNetEvent('lx-army:duty:state', function(state)
    isOnDuty = state and true or false
end)

CreateThread(function()
    while true do
        local pd = ESX.GetPlayerData()
        if pd and pd.job and pd.job.name == Config.Job then
            local c = GetEntityCoords(PlayerPedId())
            TriggerServerEvent('lx-army:duty:pos', c.x, c.y, c.z)
            Wait(2000)
        else
            Wait(1500)
        end
    end
end)


RegisterNetEvent('lx-army:duty:positions', function(pack)
    local seen = {}
    for _, t in ipairs(pack) do
        seen[t.id] = true
        ensureBlip(t.id, t)
    end
    for id, bl in pairs(dutyBlips) do
        if not seen[id] then
            if DoesBlipExist(bl) then RemoveBlip(bl) end
            dutyBlips[id] = nil
        end
    end
end)

CreateThread(function()
    Wait(500)
    TriggerServerEvent('lx-army:duty:request')
end)

CreateThread(function()
    while true do
        if isOnDuty then
            local c = GetEntityCoords(PlayerPedId())
            TriggerServerEvent('lx-army:duty:pos', c.x,c.y,c.z)
            Wait(2000)
        else
            Wait(1000)
        end
    end
end)

local function nearDuty()
    return #(GetEntityCoords(PlayerPedId()) - Config.DutyPoint) < 2.0
end

CreateThread(function()
    while Config.DutyPoint do
        if nearDuty() then
            DrawText3D(Config.DutyPoint.x, Config.DutyPoint.y, Config.DutyPoint.z,
                isOnDuty and "~y~E~w~ - OFF DUTY" or "~y~E~w~ - ON DUTY")
            if IsControlJustReleased(0,38) then
                TriggerServerEvent('lx-army:duty:toggle')
                Wait(300)
            else
                Wait(0)
            end
        else
            Wait(250)
        end
    end
end)

local function spawnRecruitNpcs()
    if not Config.Recruit or not Config.Recruit.enabled then return end
    if type(Config.Recruit.points) ~= 'table' then return end
    local model = GetHashKey(Config.Recruit.npcModel or 's_m_y_marine_01')
    RequestModel(model)
    while not HasModelLoaded(model) do Wait(0) end
    for _, p in ipairs(Config.Recruit.points) do
        local ped = CreatePed(4, model, p.x, p.y, p.z - 1.0, p.w or 0.0, false, true)
        SetEntityInvincible(ped, true)
        SetBlockingOfNonTemporaryEvents(ped, true)
        FreezeEntityPosition(ped, true)
        exports.ox_target:addLocalEntity(ped, {{
            icon = 'fa-solid fa-user-plus',
            label = 'Přihláška do armády',
            distance = 2.5,
            onSelect = function()
                SendNUIMessage({ action = 'openRecruit', schema = Config.Recruit.fields or {} })
                SetNuiFocus(true, true)
            end
        }})
        recruitPeds[#recruitPeds+1] = ped
    end
end

RegisterNUICallback('recruit:send', function(data, cb)
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'closeRecruit' })
    TriggerServerEvent('lx-army:recruit:send', data or {})
    cb(true)
end)

RegisterNUICallback('recruit:close', function(_, cb)
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'closeRecruit' })
    cb(true)
end)

CreateThread(function()
    Wait(500)
    spawnRecruitNpcs()
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for _, ped in ipairs(recruitPeds) do
        if DoesEntityExist(ped) then
            exports.ox_target:removeLocalEntity(ped)
            DeleteEntity(ped)
        end
    end
end)


CreateThread(function()
    for _, lift in pairs(Config.Elevators) do
        exports.ox_target:addSphereZone({
            coords = lift.target,
            radius = 1.5,
            debug = false,
            options = {
                {
                    name = 'elevator_' .. _,
                    event = 'lx-army:teleport',
                    icon = 'fa-solid fa-arrow-up-from-ground-water',
                    label = lift.label,
                    teleport = lift.teleport
                }
            }
        })
    end
end)

RegisterNetEvent('lx-army:teleport', function(data)
    local ped = PlayerPedId()
    local teleport = data.teleport
    DoScreenFadeOut(500)
    Wait(800)
    SetEntityCoords(ped, teleport.x, teleport.y, teleport.z)
    Wait(500)
    DoScreenFadeIn(800)
end)

RegisterNetEvent('lx-army:cac:openNui')
AddEventHandler('lx-army:cac:openNui', function(name, rank)
    SendNUIMessage({ action = 'openCAC', name = name, rank = rank })
    SetNuiFocus(true, false)
end)

RegisterNUICallback('closeCAC', function(_, cb)
    SetNuiFocus(false, false)
    cb('ok')
end)

RegisterCommand('cac', function()
    local playerData = ESX.GetPlayerData()
    if not playerData or not playerData.job then return end
     if playerData.job.name ~= Config.Job then
        ESX.ShowNotification('Nemáš vojenský průkaz', 'error')
        return
    end

    local ped = PlayerPedId()
    RequestAnimDict('paper_1_rcm_alt1-9')
    while not HasAnimDictLoaded('paper_1_rcm_alt1-9') do Wait(10) end
    TaskPlayAnim(ped, 'paper_1_rcm_alt1-9', 'player_one_dual-9', 8.0, -8.0, 2500, 49, 0, false, false, false)

    local target = GetClosestPlayer(3.0)
    local name, rank = getLocalCharInfo()

    if target then
        TriggerServerEvent('lx-army:cac:requestShow', target, name, rank)
    else
        SendNUIMessage({ action = 'openCAC', name = name, rank = rank })
        SetNuiFocus(true, false)
    end
end, false)


TriggerEvent('chat:addSuggestion', '/cac', 'Vojenský průkaz CAC')

