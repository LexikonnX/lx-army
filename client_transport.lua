local ESX = exports['es_extended']:getSharedObject()

local started = false
local carrying = false
local crate = nil
local dest = nil
local blip = nil
local npc = nil
local tankerTargetAdded = false
local missionVeh = nil
local missionTrailer = nil
local returning = false
local startNPC = nil
local picked = 0
local pkgTotal = (Config.Transport and Config.Transport.PackageCount) or 10
local mode = 'boxes'
local withTrailer = false
local truckModel = nil
local arrivedShown = false
local targetVehId = nil

local function NameBlip(b, label)
    if not b or b == 0 or not DoesBlipExist(b) then return end
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString(tostring(label or ""))
    EndTextCommandSetBlipName(b)
end

local function hintShow(text, duration)
    SendNUIMessage({ action = 'hint_show', text = text or '', duration = duration or 0 })
end

local function hintHide()
    SendNUIMessage({ action = 'hint_hide' })
end

local function clearBlip()
    if blip and DoesBlipExist(blip) then RemoveBlip(blip) end
    blip = nil
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

local function trunkOpenNeeded()
    return missionVeh and DoesEntityExist(missionVeh) and picked > 0 and picked < pkgTotal
end

local function ensureTrunkOpen()
    if not missionVeh or not DoesEntityExist(missionVeh) then return end
    local r = GetVehicleDoorAngleRatio(missionVeh, 5)
    if r < 0.05 then
        SetVehicleDoorOpen(missionVeh, 5, false, false)
    end
end

local function ensureTrunkClosed()
    if not missionVeh or not DoesEntityExist(missionVeh) then return end
    SetVehicleDoorShut(missionVeh, 5, false)
end

local function clearVehicleTarget()
    if missionVeh and DoesEntityExist(missionVeh) and tankerTargetAdded then
        exports.ox_target:removeLocalEntity(missionVeh)
        tankerTargetAdded = false
    end
end

local function spawnStartNPC()
    local pos3 = Config.Transport.Start.startZone
    if not pos3 then return end
    local head = (Config.Transport.Start.vehicleSpawn and Config.Transport.Start.vehicleSpawn.w) or 180.0
    local model = GetHashKey(Config.Transport.NPCModel or 's_m_m_marine_01')
    RequestModel(model)
    while not HasModelLoaded(model) do Wait(0) end
    startNPC = CreatePed(4, model, pos3.x, pos3.y, pos3.z - 1.0, head, false, true)
    SetEntityInvincible(startNPC, true)
    SetBlockingOfNonTemporaryEvents(startNPC, true)
    FreezeEntityPosition(startNPC, true)
    exports.ox_target:addLocalEntity(startNPC, {
        {
            icon = 'fa-solid fa-truck',
            label = Config.Transport.Text.startPrompt or 'Zahájit transport',
            distance = Config.Transport.Start.startRadius or 2.5,
            canInteract = function(entity, distance)
                if entity ~= startNPC or started or distance > (Config.Transport.Start.startRadius or 2.5) then
                    return false
                end
                local playerData = ESX.GetPlayerData()
                return playerData.job and playerData.job.name == Config.Job
            end,
            onSelect = function()
                TriggerEvent('saa:transport:req')
            end
        },
        {
            icon = 'fa-solid fa-ban',
            label = (Config.Transport.Text and Config.Transport.Text.cancelPrompt) or 'Zrušit transport',
            distance = Config.Transport.Start.startRadius or 2.5,
            canInteract = function(entity, distance)
                if entity ~= startNPC or not started or distance > (Config.Transport.Start.startRadius or 2.5) then
                    return false
                end
                local playerData = ESX.GetPlayerData()
                return playerData.job and playerData.job.name == Config.Job
            end,
            onSelect = function()
                TriggerServerEvent('saa:transport:cancel')
            end
        }
    })
end

local function deleteStartNPC()
    if startNPC and DoesEntityExist(startNPC) then
        exports.ox_target:removeLocalEntity(startNPC)
        DeleteEntity(startNPC)
    end
    startNPC = nil
end

local function makeRouteBlip(v3, name, sprite)
    if not v3 or not v3.x or not v3.y or not v3.z then return end
    clearBlip()
    blip = AddBlipForCoord(v3.x+0.0, v3.y+0.0, v3.z+0.0)
    SetBlipSprite(blip, sprite or 280)
    SetBlipDisplay(blip, 4)
    SetBlipScale(blip, 0.9)
    SetBlipColour(blip, Config.BlipColor.yellow or 46)
    SetBlipAsShortRange(blip, false)
    SetBlipRoute(blip, true)
    SetBlipRouteColour(blip, Config.BlipColor.yellow or 46)
    NameBlip(blip, name or 'Cíl')
end

local function draw3D(x, y, z, text)
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

local function loadAnimDict(dict)
    RequestAnimDict(dict)
    while not HasAnimDictLoaded(dict) do Wait(0) end
end

local function startCarryAnim()
    local ped = PlayerPedId()
    loadAnimDict('anim@heists@box_carry@')
    TaskPlayAnim(ped, 'anim@heists@box_carry@', 'idle', 4.0, -4.0, -1, 49, 0, false, false, false)
end

local function stopCarryAnim()
    ClearPedTasksImmediately(PlayerPedId())
end

local function spawnNPC(pos)
    local model = GetHashKey(Config.Transport.NPCModel or 's_m_m_marine_01')
    RequestModel(model)
    while not HasModelLoaded(model) do Wait(0) end
    npc = CreatePed(4, model, pos.x, pos.y, pos.z - 1.0, pos.w, false, true)
    SetEntityInvincible(npc, true)
    SetBlockingOfNonTemporaryEvents(npc, true)
    FreezeEntityPosition(npc, true)
    exports.ox_target:addLocalEntity(npc, {
        {
            icon = 'fa-solid fa-box',
            label = Config.Transport.Text.deliverPrompt or 'Předat náklad',
            distance = dest and (dest.dropRadius or 2.5) or 2.5,
            canInteract = function(entity, distance)
                return started and npc == entity and carrying and distance <= (dest and (dest.dropRadius or 2.5) or 2.5) and mode == 'boxes'
            end,
            onSelect = function()
                if carrying then
                    TriggerServerEvent('saa:transport:delivered')
                    if crate and DoesEntityExist(crate) then DeleteEntity(crate) end
                    crate = nil
                    carrying = false
                    stopCarryAnim()
                end
            end
        }
    })
end

local function deleteNPC()
    if npc and DoesEntityExist(npc) then
        exports.ox_target:removeLocalEntity(npc)
        DeleteEntity(npc)
    end
    npc = nil
end

local function attachCrate()
    local ped = PlayerPedId()
    local m = GetHashKey(Config.Transport.BoxModel or 'prop_cs_cardbox_01')
    RequestModel(m)
    while not HasModelLoaded(m) do Wait(0) end
    crate = CreateObject(m, 0.0, 0.0, 0.0, true, true, false)
    AttachEntityToEntity(crate, ped, GetPedBoneIndex(ped, 28422), 0.15, 0.02, -0.02, 0.0, 0.0, 0.0, true, true, false, true, 2, true)
    carrying = true
    SetCurrentPedWeapon(ped, `WEAPON_UNARMED`, true)
    startCarryAnim()
    TriggerServerEvent('saa:transport:setCarrying', true)
    picked = math.min(picked + 1, pkgTotal)
    if picked == 1 then
        ensureTrunkOpen()
    elseif picked >= pkgTotal then
        ensureTrunkClosed()
    end
end

local function detachCrate()
    if crate and DoesEntityExist(crate) then DeleteEntity(crate) end
    crate = nil
    carrying = false
    stopCarryAnim()
    TriggerServerEvent('saa:transport:setCarrying', false)
end

local function nearestRearCoord(veh)
    local off = Config.Transport.Tanker.rearOffset or vector3(0.0, -4.0, 0.0)
    local vx, vy, vz = table.unpack(GetOffsetFromEntityInWorldCoords(veh, off.x, off.y, off.z))
    return vector3(vx, vy, vz)
end

local function addVehicleTargetBoxes()
    if not missionVeh or not DoesEntityExist(missionVeh) then return end
    if targetVehId then
        exports.ox_target:removeLocalEntity(missionVeh)
        targetVehId = nil
    end
    exports.ox_target:addLocalEntity(missionVeh, {
        {
            icon = 'fa-solid fa-dolly',
            label = Config.Transport.Text.unloadPrompt or 'Vyložit náklad',
            distance = 2.5,
            canInteract = function(entity)
                if not started or carrying then return false end
                if entity ~= missionVeh then return false end
                if picked >= pkgTotal then return false end
                local rear = nearestRearCoord(entity)
                local p = GetEntityCoords(PlayerPedId())
                return #(p - rear) <= 2.0 and mode == 'boxes'
            end,
            onSelect = function()
                if not carrying and picked < pkgTotal then
                    attachCrate()
                end
            end
        }
    })
    targetVehId = true
end

local function addVehicleTargetTankerDetach()
    if not missionVeh or not DoesEntityExist(missionVeh) or tankerTargetAdded then return end
    exports.ox_target:addLocalEntity(missionVeh, {
        {
            icon = 'fa-solid fa-link-slash',
            label = Config.Transport.Text.tankerDetach or 'Odpojit cisternu',
            distance = 2.5,
            canInteract = function(entity)
                if not started or mode ~= 'tanker_drop' then return false end
                if entity ~= missionVeh then return false end
                if not IsVehicleAttachedToTrailer(missionVeh) then return false end
                local rear = nearestRearCoord(entity)
                local p = GetEntityCoords(PlayerPedId())
                return #(p - rear) <= 2.0
            end,
            onSelect = function()
                local ped = PlayerPedId()
                TaskStartScenarioInPlace(ped, 'WORLD_HUMAN_VEHICLE_MECHANIC', 0, true)
                Wait(Config.Transport.Tanker.detachTime or 3000)
                ClearPedTasksImmediately(ped)
                local attached, tr = GetVehicleTrailerVehicle(missionVeh)
                DetachVehicleFromTrailer(missionVeh)
                if attached and tr and tr ~= 0 then
                    local net = NetworkGetNetworkIdFromEntity(tr)
                    TriggerServerEvent('saa:transport:setTrailer', net)
                end
                TriggerServerEvent('saa:transport:tankerDetached')
                clearVehicleTarget()
            end
        }
    })
    tankerTargetAdded = true
end

local function spawnTrailerAtDestination()
    if not dest then return end
    local sp = dest.trailerSpawn
    if not sp then sp = vector4(dest.dropZone.x, dest.dropZone.y, dest.dropZone.z, 0.0) end
    local mdl = GetHashKey(Config.Transport.Tanker.TankerTrailer or Config.Transport.TankerTrailer or 'armytanker')
    RequestModel(mdl)
    while not HasModelLoaded(mdl) do Wait(0) end
    ClearAreaOfVehicles(sp.x, sp.y, sp.z, 6.0, false, false, false, false, false)
    missionTrailer = CreateVehicle(mdl, sp.x, sp.y, sp.z, sp.w, true, true)
    SetVehicleOnGroundProperly(missionTrailer)
    local net = NetworkGetNetworkIdFromEntity(missionTrailer)
    SetNetworkIdCanMigrate(net, true)
    TriggerServerEvent('saa:transport:setTrailer', net)
end

local function tryAutoAttach()
    if not missionVeh or not DoesEntityExist(missionVeh) then return false end
    if not missionTrailer or not DoesEntityExist(missionTrailer) then return false end
    local vpos = GetEntityCoords(missionVeh)
    local tpos = GetEntityCoords(missionTrailer)
    if #(vpos - tpos) <= (Config.Transport.Tanker.attachRadius or 8.0) and GetEntitySpeed(missionVeh) < 1.0 then
        AttachVehicleToTrailer(missionVeh, missionTrailer, 1.0)
        return true
    end
    return false
end

local function isSpotFree(v4, radius)
    local r = radius or 6.5
    if IsAnyVehicleNearPoint(v4.x, v4.y, v4.z, r) then return false end
    return true
end

local function spawnMissionVehicle()
    local mdl = GetHashKey(truckModel or Config.Transport.BoxModeTruck or 'barracks')
    RequestModel(mdl)
    while not HasModelLoaded(mdl) do Wait(0) end
    local sp = Config.Transport.Start.vehicleSpawn
    local sx, sy, sz, sh = sp.x, sp.y, sp.z, sp.w
    if startNPC and DoesEntityExist(startNPC) then
        local npos = GetEntityCoords(startNPC)
        local d = #(vector3(sx,sy,sz) - npos)
        if d < 5.0 then
            local rad = math.rad(sh)
            sx = sx + math.cos(rad) * 6.0
            sy = sy + math.sin(rad) * 6.0
        end
    end
    if not isSpotFree(vector4(sx, sy, sz, sh), 6.5) then
        TriggerEvent('esx:showNotification', (Config.Transport.Text and Config.Transport.Text.spawnBusy) or 'Spawn je obsazený', 'error')
        return false
    end
    ClearAreaOfVehicles(sx, sy, sz, 6.0, false, false, false, false, false)
    ClearAreaOfPeds(sx, sy, sz, 3.0, 0)
    missionVeh = CreateVehicle(mdl, sx, sy, sz, sh, true, true)
    SetVehicleOnGroundProperly(missionVeh)
    SetEntityAsMissionEntity(missionVeh, true, true)
    SetVehicleEngineOn(missionVeh, true, true, false)
    SetVehicleDoorsLocked(missionVeh, 1)
    SetVehicleDoorsLockedForAllPlayers(missionVeh, false)
    SetVehicleDoorsLockedForPlayer(missionVeh, PlayerId(), false)
    TaskWarpPedIntoVehicle(PlayerPedId(), missionVeh, -1)
    local plate = GetVehicleNumberPlateText(missionVeh)
    TriggerEvent('vehiclekeys:client:SetOwner', plate)
    TriggerEvent('qb-vehiclekeys:client:SetOwner', plate)
    local netId = NetworkGetNetworkIdFromEntity(missionVeh)
    SetNetworkIdCanMigrate(netId, true)
    TriggerServerEvent('saa:transport:setVeh', netId)
    if mode == 'boxes' then
        addVehicleTargetBoxes()
    end
    if mode == 'tanker_drop' and withTrailer then
        local tmdl = GetHashKey(Config.Transport.TankerTrailer or 'armytanker')
        RequestModel(tmdl)
        while not HasModelLoaded(tmdl) do Wait(0) end
        local behind = GetOffsetFromEntityInWorldCoords(missionVeh, 0.0, -6.0, 0.0)
        ClearAreaOfVehicles(behind.x, behind.y, behind.z, 6.0, false, false, false, false, false)
        missionTrailer = CreateVehicle(tmdl, behind.x, behind.y, behind.z, GetEntityHeading(missionVeh), true, true)
        SetVehicleOnGroundProperly(missionTrailer)
        AttachVehicleToTrailer(missionVeh, missionTrailer, 1.0)
        local tnet = NetworkGetNetworkIdFromEntity(missionTrailer)
        SetNetworkIdCanMigrate(tnet, true)
        TriggerServerEvent('saa:transport:setTrailer', tnet)
    end
    return true
end

local function startTransport()
    if started then
        TriggerEvent('esx:showNotification', Config.Transport.Text.alreadyRun or 'Transport už běží')
        return
    end
    TriggerServerEvent('saa:transport:start')
end

RegisterNetEvent('saa:transport:started', function(data)
    started = true
    picked = 0
    pkgTotal = (Config.Transport and Config.Transport.PackageCount) or 10
    mode = data.mode or 'boxes'
    withTrailer = data.withTrailer and true or false
    truckModel = data.truck or Config.Transport.BoxModeTruck

    dest = nil
    local label = data.dest
    for _, d in ipairs(Config.Transport.Destinations) do
        if d.id == data.dest then
            dest = d
            label = d.label or d.id
            break
        end
    end
    if not dest then
        started = false
        return
    end

    arrivedShown = false
    hintShow('Destinace: '..label..'. Vyjeď podle trasy.', 10000)
    makeRouteBlip(dest.dropZone, label, 280)

    local ok = spawnMissionVehicle()
    if not ok then
        TriggerServerEvent('saa:transport:cancel')
        started = false
        clearBlip()
        hintShow((Config.Transport.Text and Config.Transport.Text.spawnBusy) or 'Spawn je obsazený', 5000)
        return
    end

    if mode == 'tanker_drop' then
        addVehicleTargetTankerDetach()
    end
end)

RegisterNetEvent('saa:transport:pkgleft', function(left, total)
    TriggerEvent('esx:showNotification', (Config.Transport.Text.leftInfo or 'Zbývá: ') .. tostring(left) .. '/' .. tostring(total))
end)

RegisterNetEvent('saa:transport:tanker_ok', function()
    clearVehicleTarget()
    returning = true
    detachCrate()
    ensureTrunkClosed()
    local backPos = (Config.Transport.Start.vehicleReturn or Config.Transport.Start.startZone)
    makeRouteBlip(backPos, Config.Transport.Text.returnBlip or 'Návrat na základnu', 280)
    hintShow('Úkol splněn. Vrať se na základnu.', 10000)
end)

RegisterNetEvent('saa:transport:delivered_ack', function()
    hintShow('Úkol splněn. Vrať se na základnu.', 10000)
    returning = true
    detachCrate()
    ensureTrunkClosed()
    local backPos = (Config.Transport.Start.vehicleReturn or Config.Transport.Start.startZone)
    makeRouteBlip(backPos, Config.Transport.Text.returnBlip or 'Návrat na základnu', 280)
end)

local function showBanner(sfName, title, subtitle, duration)
    local sc = RequestScaleformMovie(sfName)
    while not HasScaleformMovieLoaded(sc) do
        Wait(0)
    end
    PlaySoundFrontend(-1, "PROPERTY_PURCHASE", "HUD_AWARDS", true)
    BeginScaleformMovieMethod(sc, 'SHOW_SHARD_MIDSIZED_MESSAGE')
    PushScaleformMovieMethodParameterString(title)
    PushScaleformMovieMethodParameterString(subtitle)
    EndScaleformMovieMethod()
    local t = GetGameTimer() + (duration or 4000)
    while GetGameTimer() < t do
        DrawScaleformMovieFullscreen(sc, 255, 255, 255, 255, 0)
        Wait(0)
    end
    BeginScaleformMovieMethod(sc, 'SHARD_ANIM_OUT')
    PushScaleformMovieMethodParameterInt(1)
    PushScaleformMovieMethodParameterFloat(0.35)
    EndScaleformMovieMethod()
    Wait(600)
    SetScaleformMovieAsNoLongerNeeded(sc)
end

RegisterNetEvent('saa:transport:finished', function(paid)
    hintHide()
    clearVehicleTarget()
    started = false
    returning = false
    picked = 0
    detachCrate()
    clearBlip()
    deleteNPC()
    if missionVeh and DoesEntityExist(missionVeh) then DeleteEntity(missionVeh) end
    if missionTrailer and DoesEntityExist(missionTrailer) then DeleteEntity(missionTrailer) end
    missionVeh = nil
    missionTrailer = nil
    if paid then
        showBanner('MIDSIZED_MESSAGE', Config.Transport.Text.returnOk, 4000)
        TriggerEvent('esx:showNotification', Config.Transport.Text.returnOk or 'Hotovo')
    end
end)

CreateThread(function()
    while true do
        if started and mode == 'boxes' and trunkOpenNeeded() then
            ensureTrunkOpen()
        end
        Wait(500)
    end
end)

RegisterNetEvent('saa:transport:req', function()
    if started then
        TriggerEvent('esx:showNotification', Config.Transport.Text.alreadyRun or 'Transport už běží')
        return
    end
    TriggerServerEvent('saa:transport:start')
end)

CreateThread(function()
    while true do
        if started then
            if dest and not npc then spawnNPC(dest.npcPos) end
            if carrying then
                DisableControlAction(0, 21, true)
                DisableControlAction(0, 22, true)
                DisableControlAction(0, 23, true)
                DisableControlAction(0, 24, true)
                DisableControlAction(0, 25, true)
            end

            if mode == 'tanker_pick' and dest and missionVeh and DoesEntityExist(missionVeh) then
                local ppos = GetEntityCoords(missionVeh)
                local dpos = dest.dropZone
                local dist = #(ppos - dpos)
                if dist < 60.0 and not missionTrailer then
                    spawnTrailerAtDestination()
                end
                if dist < 60.0 and not arrivedShown then
                    hintShow('Připojení cisterny. Couvni k cisterně v zóně a připoj ji pomalu.', 0)
                    arrivedShown = true
                end
                if missionTrailer and not IsVehicleAttachedToTrailer(missionVeh) then
                    if tryAutoAttach() then
                        TriggerServerEvent('saa:transport:tankerAttached')
                    end
                end
            end

            if mode == 'tanker_drop' and dest and missionVeh and DoesEntityExist(missionVeh) then
                local p = GetEntityCoords(missionVeh)
                local d = #(p - dest.dropZone)
                if d < 35.0 then
                    if not tankerTargetAdded then addVehicleTargetTankerDetach() end
                    if not arrivedShown then
                        hintShow('Zastav v zóně, jdi dozadu k tiráku a přes target odpoj cisternu.', 0)
                        arrivedShown = true
                    end
                else
                    if tankerTargetAdded then clearVehicleTarget() end
                end
            end

            if mode == 'boxes' and dest and missionVeh and DoesEntityExist(missionVeh) then
                local d = #(GetEntityCoords(missionVeh) - dest.dropZone)
                if d < 35.0 and not arrivedShown then
                    hintShow('Zastav v zóně, jdi dozadu k autu, přes target vylož všech '..Config.Transport.PackageCount..' beden a podej je skladníkovi.', 0)
                    arrivedShown = true
                end
            end
        end
        Wait(0)
    end
end)

CreateThread(function()
    while true do
        if returning and missionVeh and DoesEntityExist(missionVeh) then
            local ped = PlayerPedId()
            local rz = _returnPos()
            local rr = _returnRadius()
            local vpos = GetEntityCoords(missionVeh)
            local ppos = GetEntityCoords(ped)
            local inZone = (#(vpos - rz) < rr) or (#(ppos - rz) < rr)
            if inZone then
                local onDriver = IsPedInVehicle(ped, missionVeh, false) and GetPedInVehicleSeat(missionVeh, -1) == ped
                local nearVeh = (#(ppos - vpos) < 4.0)
                if onDriver or nearVeh then
                    draw3D(rz.x, rz.y, rz.z + 1.0, Config.Transport.Text.returnPrompt or 'Vrátit vozidlo na základnu')
                    if IsControlJustReleased(0, 38) then
                        TriggerServerEvent('saa:transport:return')
                    end
                else
                    draw3D(rz.x, rz.y, rz.z + 1.0, Config.Transport.Text.needMissionVeh or 'Přijeď s vozidlem blíž')
                end
            end
        end
        Wait(0)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    hintHide()
    clearVehicleTarget()
    clearBlip()
    deleteNPC()
    detachCrate()
    if missionVeh and DoesEntityExist(missionVeh) then DeleteEntity(missionVeh) end
    if missionTrailer and DoesEntityExist(missionTrailer) then DeleteEntity(missionTrailer) end
    if startNPC and DoesEntityExist(startNPC) then DeleteEntity(startNPC) end
end)

CreateThread(function()
    spawnStartNPC()
end)
