local ESX = exports['es_extended']:getSharedObject()

local usingBino = false
local binoCam = nil
local sf = 0
local fov = 18.0
local fovMin = 3.0
local fovMax = 45.0
local cancelKey = 177
local prop = 0

local function stopBino()
    usingBino = false
    ClearPedTasksImmediately(PlayerPedId())
    if DoesCamExist(binoCam) then
        RenderScriptCams(false, false, 0, true, true)
        DestroyCam(binoCam, false)
        binoCam = nil
    end
    if sf ~= 0 then
        SetScaleformMovieAsNoLongerNeeded(sf)
        sf = 0
    end
    if DoesEntityExist(prop) then
        DetachEntity(prop, true, true)
        DeleteObject(prop)
        prop = 0
    end
    DisplayRadar(true)
end

local function startBino()
    if usingBino then return end
    usingBino = true

    local ped = PlayerPedId()

    RequestAnimDict('amb@world_human_binoculars@male@base')
    while not HasAnimDictLoaded('amb@world_human_binoculars@male@base') do Wait(0) end
    TaskPlayAnim(ped, 'amb@world_human_binoculars@male@base', 'base', 8.0, -8.0, -1, 49, 0, false, false, false)

    local model = GetHashKey('prop_binoc_01')
    RequestModel(model)
    while not HasModelLoaded(model) do Wait(0) end
    prop = CreateObject(model, 0.0,0.0,0.0, true, true, false)
    AttachEntityToEntity(prop, ped, GetPedBoneIndex(ped, 28422), 0.0,0.0,0.0, 0.0,0.0,0.0, true, true, false, true, 1, true)
    SetModelAsNoLongerNeeded(model)

    sf = RequestScaleformMovie('BINOCULARS')
    while sf == 0 do
        sf = RequestScaleformMovie('BINOCULARS')
        Wait(0)
    end

    binoCam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    RenderScriptCams(true, false, 0, true, true)
    fov = 18.0

    SetFollowPedCamViewMode(4) -- první osoba
    SetCamActive(binoCam, true)
    DisplayRadar(false)
    TriggerEvent('chat:clear') -- vyčistí chat

    CreateThread(function()
        while usingBino do
            Wait(0)
            HideHudAndRadarThisFrame()
            local pos = GetPedBoneCoords(ped, 31086, 0.0, 0.05, 0.0)
            local rot = GetGameplayCamRot(2)
            SetCamCoord(binoCam, pos.x, pos.y, pos.z)
            SetCamRot(binoCam, rot.x, rot.y, rot.z, 2)
            SetCamFov(binoCam, fov)
            DrawScaleformMovieFullscreen(sf, 255, 255, 255, 255, 0)

            if IsControlJustPressed(0, 241) then fov = math.max(fovMin, fov - 2.0) end
            if IsControlJustPressed(0, 242) then fov = math.min(fovMax, fov + 2.0) end

            BeginTextCommandDisplayHelp('STRING')
            AddTextComponentSubstringPlayerName('Zoom ~INPUT_WEAPON_WHEEL_NEXT~/~INPUT_WEAPON_WHEEL_PREV~\nUkončit ~INPUT_CELLPHONE_CANCEL~')
            EndTextCommandDisplayHelp(0, false, true, -1)

            if IsControlJustPressed(0, cancelKey) then
                stopBino()
            end
        end
    end)
end

RegisterCommand('bino', function()
    local pd = ESX.GetPlayerData()
    if not pd or not pd.job or pd.job.name ~= Config.Job then return end
    if usingBino then
        stopBino()
    else
        startBino()
    end
end, false)

TriggerEvent('chat:addSuggestion', '/bino', 'Binoculars (zoom, overlay). Backspace to exit')
