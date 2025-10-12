local ESX = exports['es_extended']:getSharedObject()

local started = false
local heli = nil
local cargo = nil
local blip = nil
local dest = nil
local returning = false
local startNPC = nil
local attached = false
local arrivedShown = false

local function NameBlip(b, label)
    if not b or b == 0 or not DoesBlipExist(b) then return end
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString(tostring(label or ""))
    EndTextCommandSetBlipName(b)
end

local function hintShow(text, duration)
    SendNUIMessage({ action = 'hint_show', text = text or '', duration = duration or 0 })
end

local cityWarnLast = 0

local function _cityCfg()
    local c = Config.AirTransport and Config.AirTransport.city
    if not c then return nil end
    local isVec = type(c) == 'vector3' or (c.x and c.y and c.z and not c.radius)
    if isVec then
        return {
            center = c,
            radius = 1800.0,
            minHAG = 120.0,
            warnEvery = 1200,
            debug = true,
            debugHeight = 250.0,
            debugDuringMission = false
        }
    else
        return {
            center = c.center or vector3(0.0,0.0,0.0),
            radius = c.radius or 1800.0,
            minHAG = c.minHAG or 120.0,
            warnEvery = c.warnEvery or 1200,
            debug = (c.debug ~= false),
            debugHeight = c.debugHeight or 250.0,
            debugDuringMission = (c.debugDuringMission == true)
        }
    end
end

local function _drawCityDebug(cfg)
    if not cfg or not cfg.debug then return end
    DrawMarker(1, cfg.center.x, cfg.center.y, cfg.center.z - 1.0, 0.0,0.0,0.0, 0.0,0.0,0.0, cfg.radius * 2.0, cfg.radius * 2.0, cfg.debugHeight, 255, 60, 60, 60, false, false, 0, false)
end

CreateThread(function()
    while true do
        local cfg = _cityCfg()
        if cfg and cfg.debug and not started then
            _drawCityDebug(cfg)
        end
        Wait(0)
    end
end)

local function _checkCityLow()
    if not started or not heli or not DoesEntityExist(heli) then return end
    local cfg = _cityCfg()
    if not cfg then return end
    if cfg.debugDuringMission then _drawCityDebug(cfg) end
    local pos = GetEntityCoords(heli)
    local inCity = #(pos - cfg.center) <= cfg.radius
    if not inCity then return end
    local hag = GetEntityHeightAboveGround(heli)
    if hag < cfg.minHAG then
        local now = GetGameTimer()
        if now - cityWarnLast >= cfg.warnEvery then
            PlaySoundFrontend(-1, 'TIMER_STOP', 'HUD_MINI_GAME_SOUNDSET', true)
            hintShow(Config.AirTransport.Text.lowCity or ('Varování: letíš nízko nad městem!'), cfg.warnEvery - 50)
            cityWarnLast = now
        end
    end
end


local function hintHide()
    SendNUIMessage({ action = 'hint_hide' })
end

local function clearBlip()
    if blip and DoesBlipExist(blip) then RemoveBlip(blip) end
    blip = nil
end

local function netPersist(ent)
    if not DoesEntityExist(ent) then return end
    local net = NetworkGetNetworkIdFromEntity(ent)
    SetNetworkIdExistsOnAllMachines(net, true)
    SetNetworkIdCanMigrate(net, false)
    NetworkSetNetworkIdDynamic(net, false)

    if SetEntityDistanceCullingRadius then
        pcall(function() SetEntityDistanceCullingRadius(ent, 1200.0) end)
    end
    if SetEntityLodDist then
        pcall(function() SetEntityLodDist(ent, 999999) end)
    end

    return net
end

local function rayDownAt(pos, maxDrop)
    local from = vector3(pos.x, pos.y, pos.z + 10.0)
    local to   = vector3(pos.x, pos.y, pos.z - (maxDrop or 30.0))
    local ray = StartShapeTestRay(from.x, from.y, from.z, to.x, to.y, to.z, 1, 0, 7)
    local _, hit, hitPos = GetShapeTestResult(ray)
    if hit == 1 then return hitPos end
    return nil
end

local function makeRouteBlip(v3, name, sprite, color)
    if not v3 or not v3.x then return end
    clearBlip()
    blip = AddBlipForCoord(v3.x+0.0, v3.y+0.0, v3.z+0.0)
    SetBlipSprite(blip, sprite or (Config.AirTransport.Blip and Config.AirTransport.Blip.sprite) or 64)
    SetBlipDisplay(blip, 4)
    SetBlipScale(blip, 0.9)
    SetBlipColour(blip, color or (Config.AirTransport.Blip and Config.AirTransport.Blip.color) or 46)
    SetBlipAsShortRange(blip, false)
    SetBlipRoute(blip, true)
    SetBlipRouteColour(blip, color or (Config.AirTransport.Blip and Config.AirTransport.Blip.color) or 46)
    NameBlip(blip, name or 'Cíl')
end

local function hasOxTarget()
    return exports and exports.ox_target and exports.ox_target.addLocalEntity ~= nil
end

local function registerTarget(entity)
    if not hasOxTarget() then return end
    exports.ox_target:addLocalEntity(entity, {
        {
            icon = 'fa-solid fa-helicopter',
            label = Config.AirTransport.Text.startPrompt or 'Zahájit letecký transport',
            distance = Config.AirTransport.Start.startRadius or 2.5,
            canInteract = function(entity, distance)
                if started or entity ~= startNPC then return false end
                local playerData = ESX.GetPlayerData()
                return playerData.job and playerData.job.name == Config.Job and distance <= (Config.AirTransport.Start.startRadius or 2.5)
            end,
            onSelect = function()
                TriggerEvent('saa:air:req')
            end
        },
        {
            icon = 'fa-solid fa-ban',
            label = Config.AirTransport.Text.cancelPrompt or 'Zrušit letecký transport',
            distance = Config.AirTransport.Start.startRadius or 2.5,
            canInteract = function(entity, distance)
                if not started or entity ~= startNPC then return false end
                local playerData = ESX.GetPlayerData()
                return playerData.job and playerData.job.name == Config.Job and distance <= (Config.AirTransport.Start.startRadius or 2.5)
            end,
            onSelect = function()
                TriggerServerEvent('saa:air:cancel')
            end
        }
    })
end

local function spawnStartNPC()
    local pos = Config.AirTransport.Start.startZone
    if not pos then return end
    local model = GetHashKey('s_m_m_marine_01')
    RequestModel(model)
    while not HasModelLoaded(model) do Wait(0) end
    if startNPC and DoesEntityExist(startNPC) then DeleteEntity(startNPC) end
    startNPC = CreatePed(4, model, pos.x, pos.y, pos.z - 1.0, 60.0, false, true)
    SetEntityAsMissionEntity(startNPC, true, true)
    SetEntityInvincible(startNPC, true)
    SetBlockingOfNonTemporaryEvents(startNPC, true)
    FreezeEntityPosition(startNPC, true)
    registerTarget(startNPC)
end

CreateThread(function()
    spawnStartNPC()
    while true do
        if startNPC and not DoesEntityExist(startNPC) then
            spawnStartNPC()
        end
        if not hasOxTarget() and startNPC and not started then
            local p = GetEntityCoords(PlayerPedId())
            local s = Config.AirTransport.Start.startZone
            if #(p - s) <= (Config.AirTransport.Start.startRadius or 2.5) then
                SetTextCentre(1)
                SetTextEntry("STRING")
                AddTextComponentString(Config.AirTransport.Text.startPrompt or 'Zahájit letecký transport')
                DrawText(0.5, 0.88)
                if IsControlJustReleased(0, 38) then
                    TriggerEvent('saa:air:req')
                end
            end
        elseif not hasOxTarget() and startNPC and started then
            local p = GetEntityCoords(PlayerPedId())
            local s = Config.AirTransport.Start.startZone
            if #(p - s) <= (Config.AirTransport.Start.startRadius or 2.5) then
                SetTextCentre(1)
                SetTextEntry("STRING")
                AddTextComponentString(Config.AirTransport.Text.cancelPrompt or 'Zrušit letecký transport')
                DrawText(0.5, 0.88)
                if IsControlJustReleased(0, 38) then
                    TriggerServerEvent('saa:air:cancel')
                end
            end
        end
        Wait(300)
    end
end)

local function deleteStartNPC()
    if startNPC and DoesEntityExist(startNPC) then
        if hasOxTarget() then
            exports.ox_target:removeLocalEntity(startNPC)
        end
        DeleteEntity(startNPC)
    end
    startNPC = nil
end

local function isPadFree(v4, radius)
    local r = radius or 6.0
    if IsAnyVehicleNearPoint(v4.x, v4.y, v4.z, r) then return false end
    return true
end

local function spawnAt(v4, mdl)
    if not isPadFree(v4, 6.5) then return false end
    heli = CreateVehicle(mdl, v4.x, v4.y, v4.z, v4.w, true, true)
    SetVehicleOnGroundProperly(heli)
    SetEntityAsMissionEntity(heli, true, true)
    SetVehicleEngineOn(heli, true, true, false)
    TaskWarpPedIntoVehicle(PlayerPedId(), heli, -1)
    local plate = GetVehicleNumberPlateText(heli)
    TriggerEvent('vehiclekeys:client:SetOwner', plate)
    TriggerEvent('qb-vehiclekeys:client:SetOwner', plate)
    local net = NetworkGetNetworkIdFromEntity(heli)
    SetNetworkIdCanMigrate(net, true)
    TriggerServerEvent('saa:air:setHeli', net)
    return true
end

local function spawnHeli()
    local sp1 = Config.AirTransport.Start.heliSpawn
    local sp2 = Config.AirTransport.Start.heliSpawn2
    local mdl = GetHashKey(Config.AirTransport.HeliModel or 'cargobob')
    RequestModel(mdl)
    while not HasModelLoaded(mdl) do Wait(0) end
    if spawnAt(sp1, mdl) then return true end
    if sp2 and spawnAt(sp2, mdl) then
        TriggerEvent('esx:showNotification', Config.AirTransport.Text.spawnedAtAlt or 'Vrtulník je na záložním helipadu')
        return true
    end
    TriggerEvent('esx:showNotification', Config.AirTransport.Text.helipadBusy or 'Helipad je obsazený', 'error')
    return false
end

local lastCargoSpawn = 0

local function spawnCargoAt(v3)
    local now = GetGameTimer()
    if now - lastCargoSpawn < 1500 then return end
    lastCargoSpawn = now

    local mdl = GetHashKey(Config.AirTransport.CargoModel or 'prop_mil_crate_01')
    RequestModel(mdl)
    while not HasModelLoaded(mdl) do Wait(0) end

    local hitPos = rayDownAt(v3, 60.0) or v3
    local cz = (hitPos.z or v3.z) + 0.05

    ClearAreaOfObjects(v3.x, v3.y, cz, 3.0, 0)
    if cargo and DoesEntityExist(cargo) then DeleteEntity(cargo) end

    cargo = CreateObjectNoOffset(mdl, v3.x, v3.y, cz, true, true, false)
    SetEntityAsMissionEntity(cargo, true, true)
    SetEntityCollision(cargo, true, true)
    FreezeEntityPosition(cargo, false)
    SetModelAsNoLongerNeeded(mdl)

    local net = netPersist(cargo)
    TriggerServerEvent('saa:air:setCargo', net)

    if hasOxTarget() then
        exports.ox_target:addLocalEntity(cargo, {{
            icon = 'fa-solid fa-anchor',
            label = Config.AirTransport.Text.attachHint or 'Uchytit náklad',
            distance = 2.0,
            canInteract = function() return false end,
            onSelect = function() end
        }})
    end
end

local function attachIfClose()
    if not heli or not DoesEntityExist(heli) then return end
    if not cargo or not DoesEntityExist(cargo) then return end
    if attached then return end
    local hpos = GetEntityCoords(heli)
    local cpos = GetEntityCoords(cargo)
    local d = #(hpos - cpos)
    local dz = math.abs(hpos.z - cpos.z)
    if d <= (Config.AirTransport.Attach.radius or 6.0) and dz <= (Config.AirTransport.Attach.heightMax or 8.0) and GetEntitySpeed(heli) < 3.0 then
        AttachEntityToEntity(cargo, heli, 0, 0.0, 0.0, -3.8, 0.0, 0.0, 0.0, true, true, true, false, 2, true)
        attached = true
    end
end

local function detachIfInZone()
    if not attached then return false end
    if not dest then return false end
    local cpos = GetEntityCoords(cargo)
    local d = #(cpos - dest.dropZone)
    if d <= (dest.dropRadius or 8.0) then
        DetachEntity(cargo, true, true)
        PlaceObjectOnGroundProperly(cargo)
        attached = false
        return true
    end
    return false
end

local function startAir()
    if started then
        TriggerEvent('esx:showNotification', Config.AirTransport.Text.alreadyRun or 'Letecký transport už probíhá')
        return
    end
    TriggerServerEvent('saa:air:start')
end

RegisterNetEvent('saa:air:started', function(data)
    started = true
    attached = false
    returning = false
    arrivedShown = false
    dest = nil
    for _, d in ipairs(Config.AirTransport.Destinations or {}) do
        if d.id == data.dest then dest = d break end
    end
    if not dest then
        started = false
        return
    end
    local ok = spawnHeli()
    if not ok then
        TriggerServerEvent('saa:air:cancel')
        started = false
        return
    end
    spawnCargoAt(dest.pickupZone)
    makeRouteBlip(dest.pickupZone, Config.AirTransport.Text.routePick or 'Vyzvednutí', 64)
    hintShow(Config.AirTransport.Text.routePick or 'Vydej se k vyzvednutí nákladu', 8000)
end)

RegisterNetEvent('saa:air:setCargoClient', function(net)
    local ent = NetworkGetEntityFromNetworkId(net)
    if ent and ent ~= 0 then cargo = ent end
end)

RegisterNetEvent('saa:air:setHeliClient', function(net)
    local ent = NetworkGetEntityFromNetworkId(net)
    if ent and ent ~= 0 then heli = ent end
end)

RegisterNetEvent('saa:air:toDrop', function()
    makeRouteBlip(dest.dropZone, Config.AirTransport.Text.routeDrop or 'Cíl', 64)
    hintShow(Config.AirTransport.Text.routeDrop or 'Doruč náklad do cíle', 8000)
end)

RegisterNetEvent('saa:air:delivered', function()
    returning = true
    hintShow(Config.AirTransport.Text.returnInfo or 'Úkol splněn. Vrať se na základnu.', 8000)
    makeRouteBlip(Config.AirTransport.Start.vehicleReturn, Config.AirTransport.Text.returnBlip or 'Návrat na základnu', 64)
end)

RegisterNetEvent('saa:air:finished', function(paid)
    hintHide()
    clearBlip()
    started = false
    returning = false
    attached = false
    if cargo and DoesEntityExist(cargo) then DeleteEntity(cargo) end
    if heli and DoesEntityExist(heli) then DeleteEntity(heli) end
    cargo = nil
    heli = nil
    dest = nil
    if paid then
        TriggerEvent('esx:showNotification', Config.AirTransport.Text.returnOk or 'Hotovo')
    end
end)

RegisterNetEvent('saa:air:req', function()
    if started then
        TriggerEvent('esx:showNotification', Config.AirTransport.Text.alreadyRun or 'Letecký transport už probíhá')
        return
    end
    TriggerServerEvent('saa:air:start')
end)

CreateThread(function()
    while true do
        if started then
            _checkCityLow()
            if heli and dest and not cargo then
                local ppos = GetEntityCoords(heli)
                if #(ppos - dest.pickupZone) < 40.0 then
                    spawnCargoAt(dest.pickupZone)
                end
            end
            if heli and DoesEntityExist(heli) and cargo and DoesEntityExist(cargo) and not attached then
                local ppos = GetEntityCoords(heli)
                local d = #(ppos - dest.pickupZone)
                if d < 60.0 and not arrivedShown then
                    hintShow(Config.AirTransport.Text.attachHint or 'Vis nad nákladem a stiskni E pro uchycení', 0)
                    arrivedShown = true
                end
            end
            if IsControlJustReleased(0, 38) and heli and cargo then
                if not attached then
                    attachIfClose()
                    if attached then
                        TriggerServerEvent('saa:air:attached')
                    end
                else
                    local ok = detachIfInZone()
                    if ok then
                        TriggerServerEvent('saa:air:detached')
                    else
                        hintShow(Config.AirTransport.Text.detachHint or 'Leť nad cílovou zónu a stiskni E pro odpojení', 3000)
                    end
                end
            end
            if returning and heli and DoesEntityExist(heli) then
                local rz = Config.AirTransport.Start.vehicleReturn
                local rr = Config.AirTransport.Start.returnRadius or 10.0
                local vpos = GetEntityCoords(heli)
                if #(vpos - rz) <= rr then
                    DrawMarker(1, rz.x, rz.y, rz.z - 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 3.5, 3.5, 1.0, 255, 255, 0, 120, false, false, 0, false)
                    SetTextCentre(1)
                    SetTextEntry("STRING")
                    AddTextComponentString(Config.AirTransport.Text.returnPrompt or 'Vrátit vrtulník na základnu')
                    DrawText(0.5, 0.88)
                    if IsControlJustReleased(0, 38) then
                        TriggerServerEvent('saa:air:return')
                    end
                end
            end
        end
        if cargo and DoesEntityExist(cargo) and not attached then
            local c = GetEntityCoords(cargo)
            DrawMarker(2, c.x, c.y, c.z + 0.5, 0.0,0.0,0.0, 0.0,0.0,0.0, 0.6,0.6,0.6, 0,255,100,140, false,false,2,false)
        end
        Wait(0)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    hintHide()
    clearBlip()
    if cargo and DoesEntityExist(cargo) then DeleteEntity(cargo) end
    if heli and DoesEntityExist(heli) then DeleteEntity(heli) end
    if startNPC and DoesEntityExist(startNPC) then
        if hasOxTarget() then
            exports.ox_target:removeLocalEntity(startNPC)
        end
        DeleteEntity(startNPC)
    end
end)
