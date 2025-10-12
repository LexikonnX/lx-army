local ESX = exports['es_extended']:getSharedObject()
local active = false
local cancelKey = 177

local AnimPack = {
  salute      = { t='anim', d='anim@mp_player_intuppersalute', a='idle_a', f=49, loop=false },
  salute2     = { t='anim', d='anim@mp_player_intcelebrationmale@salute', a='salute', f=49, loop=false },
  guard       = { t='scenario', s='WORLD_HUMAN_GUARD_STAND', loop=true },
  clipboard   = { t='scenario', s='WORLD_HUMAN_CLIPBOARD', loop=true },
  pushups     = { t='scenario', s='WORLD_HUMAN_PUSH_UPS', loop=true },
  situps      = { t='scenario', s='WORLD_HUMAN_SIT_UPS', loop=true },
}

local function playAction(key)
  if key == 'stop' then
    ClearPedTasksImmediately(PlayerPedId())
    active = false
    return
  end
  local cfg = AnimPack[key]
  if not cfg then return end
  local ped = PlayerPedId()
  ClearPedTasksImmediately(ped)
  if cfg.t == 'scenario' then
    TaskStartScenarioInPlace(ped, cfg.s, 0, true)
    active = cfg.loop
  else
    RequestAnimDict(cfg.d)
    while not HasAnimDictLoaded(cfg.d) do Wait(0) end
    TaskPlayAnim(ped, cfg.d, cfg.a, 8.0, -8.0, cfg.loop and -1 or 2500, cfg.f or 49, 0.0, false, false, false)
    active = cfg.loop
  end
  if active then
    CreateThread(function()
      while active do
        Wait(0)
        BeginTextCommandDisplayHelp('STRING')
        AddTextComponentSubstringPlayerName('Zrušit ~INPUT_CELLPHONE_CANCEL~ nebo /aa stop')
        EndTextCommandDisplayHelp(0, false, true, -1)
        if IsControlJustPressed(0, cancelKey) then
          ClearPedTasksImmediately(ped)
          active = false
        end
      end
    end)
  end
end

RegisterCommand('aa', function(_, args)
  local pd = ESX.GetPlayerData()
  if not pd or not pd.job or pd.job.name ~= Config.Job then return end
  local key = (args[1] or ''):lower()
  if key == '' then return end
  playAction(key)
end, false)

TriggerEvent('chat:addSuggestion', '/aa', 'Vojenská animace', {
  { name = 'action', help = 'salute, salute2, guard, clipboard, pushups, situps, stop' }
})
