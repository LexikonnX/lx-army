local ESX = exports['es_extended']:getSharedObject()
local canUse = false
local nvgOn = false

local function isAllowed(ped)
    local d = GetPedPropIndex(ped, 0)
    if d == -1 then return false end
    local t = GetPedPropTextureIndex(ped, 0)
    for _, v in ipairs(Config.NightVision) do
        if d == v.drawable and (v.texture == nil or t == v.texture) then
            return true
        end
    end
    return false
end

local function setNVG(state)
    nvgOn = state
    SetNightvision(state)
end

RegisterCommand('nvg', function()
    if canUse then
        setNVG(not nvgOn)
    else
        if nvgOn then setNVG(false) end
    end
end, false)

RegisterKeyMapping('nvg', 'Toggle Night Vision', 'keyboard', Config.KeyDefault)

CreateThread(function()
    while true do
        local ped = PlayerPedId()
        local allowed = isAllowed(ped)
        if allowed ~= canUse then
            canUse = allowed
            if not canUse and nvgOn then
                setNVG(false)
            end
        end
        if IsEntityDead(ped) and nvgOn then
            setNVG(false)
        end
        Wait(Config.CheckInterval)
    end
end)

RegisterCommand('nvgdbg', function()
    local ped = PlayerPedId()
    local hatDrawable = GetPedPropIndex(ped, 0)
    local hatTexture = GetPedPropTextureIndex(ped, 0)
    local maskDrawable = GetPedDrawableVariation(ped, 1)
    local maskTexture = GetPedTextureVariation(ped, 1)
    print(('[NVG DBG] HAT drawable=%s texture=%s | MASK drawable=%s texture=%s'):format(hatDrawable, hatTexture, maskDrawable, maskTexture))
end, false)
