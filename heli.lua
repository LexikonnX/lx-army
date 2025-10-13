local ESX = exports['es_extended']:getSharedObject()

local allow = {
  'annihilator','annihilator2','buzzard','buzzard2','maverick','polmav','frogger',
  'seasparrow','seasparrow2','seasparrow3','valkyrie','valkyrie2','swift','swift2'
}
local cancelKey = 177
local active = false

local function isAllowedModel(veh)
  local m = GetEntityModel(veh)
  for _,n in ipairs(allow) do
    if m == GetHashKey(n) then return true end
  end
  return false
end

CreateThread(function()
  while true do
    Wait(0)
    local ped = PlayerPedId()
    local pd = ESX.GetPlayerData()
    if not pd or not pd.job or pd.job.name ~= Config.Job then goto continue end

    if not active and IsPedInAnyHeli(ped) and GetPedInVehicleSeat(GetVehiclePedIsIn(ped,false),-1) ~= ped then
      local heli = GetVehiclePedIsIn(ped,false)
      if isAllowedModel(heli) then
        local speed = GetEntitySpeed(heli) * 3.6
        local alt = GetEntityHeightAboveGround(heli)
        if speed < 15.0 and alt > 8.0 and alt < 60.0 then
          BeginTextCommandDisplayHelp('STRING')
          AddTextComponentSubstringPlayerName('~INPUT_CONTEXT~ Fast-rope\n~INPUT_CELLPHONE_CANCEL~ Cancel')
          EndTextCommandDisplayHelp(0, false, true, -1)
          if IsControlJustPressed(0,38) then
            RopeLoadTextures()
            TaskRappelFromHeli(ped, 0x41200000)
            active = true
          end
        end
      end
    elseif active then
      BeginTextCommandDisplayHelp('STRING')
      AddTextComponentSubstringPlayerName('~INPUT_CELLPHONE_CANCEL~ Cancel')
      EndTextCommandDisplayHelp(0, false, true, -1)
      if IsControlJustPressed(0, cancelKey) or IsPedOnFoot(ped) then
        ClearPedTasksImmediately(ped)
        active = false
      end
      if not IsPedInAnyVehicle(ped,false) and IsPedOnFoot(ped) and IsEntityInAir(ped) == false then
        active = false
      end
    end
    ::continue::
  end
end)
