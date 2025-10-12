Config = {}

Config.Job = 'army'

Config.Recruit = {
  enabled = true,
  npcModel = 's_m_y_marine_01',
  webhook = 'https://discord.com/api/webhooks/1426597353980432554/nO9gEsAtySik8ytd6pqP3h7YhO9YyVXJBLFFU_yAmfoGRtkfRNDpy7V3BPEQnyawSp16',
  avatar_url = 'https://i.imgur.com/yJLVWGa.png',
  points = {
    vector4(-2308.37, 3391.36, 30.98, 77.02),
    vector4(-1588.07, 2793.68, 16.91, 221.13)
  },
  fields = {
    { key = 'fullname', label = 'Jméno a příjmení' },
    { key = 'age', label = 'Datum narození' },
    { key = 'phone', label = 'Telefon' },
    { key = 'motivation', label = 'Životopis (min 300 znaků)' },
    { key = 'discord', label = 'Discord' }
  }
}

Config.PagerCooldown = 60
Config.MessageMax = 100
Config.PagerDuration = 20 * 1000
Config.MinGrade = 0

Config.Elevators = {
    {
        label = "Výtah nahoru",
        coords = vec3(-2361.00, 3248.82, 32.81),
        target = vec3(-2361.00, 3248.82, 32.81),
        teleport = vec3(-2361.03, 3249.17, 92.90),
    },
    {
        label = "Výtah dolů",
        coords = vec3(-2361.03, 3249.17, 92.90),
        target = vec3(-2361.03, 3249.17, 92.90),
        teleport = vec3(-2361.00, 3248.82, 32.81),
    }
}

Config.BlipSprite = 433
Config.BlipColor = {
    green = 2,
    yellow = 46,
    red = 1
}
Config.BlipDuration = 600

Config.Base = vector3(-2115.07, 3146.95, 32.81)

Config.SpawnGarageHeli = true
Config.SpawnGaragePlane = true
Config.SpawnGarageBoat = true
Config.SpawnPoint = {
    vector4(-1877.35, 2805.34, 32.81, 327.4),
    vector4(3102.76, -4734.51, 15.26, 101.06),
    vector4(-3260.66, 3986.37, 15.26, 358.28)
}
Config.SpawnPointPlane = {
    vector4(-1843.96, 2984.3, 32.81, 57.14),
    vector4(3063.72, -4773.14, 15.26, 304.87),
    vector4(-3240.68, 3893.45, 15.26, 179.97)
}
Config.SpawnGarageBoat = {
    point = vector4(-3198.26, 4013.09, 6.08, 86.89),
    spawn = vector4(-3188.38, 4005.16, 1.15, 349.65)
}
Config.Helis = {
    {label = "Valkyrie", model = "valkyrie", max = 2},
    {label = "Cargobob", model = "cargobob", max = 2},
}
Config.Planes = {
    {label = "Lazer", model = "lazer", max = 3},
    {label = "Titan", model = "titan", max = 1},
    {label = "Strike Force", model = "strikeforce", max = 1},
    --{label = "Millitary Jet", model = "miljet", max = 1}
}
Config.Boats = {
    { label = 'Boat', model = 'patrolboat', max = 1},
    --{ label = 'Avisa', model = 'avisa', max = 1},
}

Config.WeaponToggleGrade = 1
Config.WeaponBanDefault = true
Config.blacklistModels = {}

for _, list in ipairs({Config.Helis, Config.Planes, Config.Boats}) do
    for _, v in ipairs(list) do
        table.insert(Config.blacklistModels, v.model)
    end
end

Config.DutyPoint = false

Config.Transport = {
    ModeChances = { boxes = 60, tanker_drop = 40, tanker_pick = 0 },
    BoxModeTruck = 'barracks',
    TankerTruck = 'barracks2',
    TankerTrailer = 'armytanker',
    NPCModel = 's_m_m_marine_01',
    PayAccount = 'money',
    BoxModel = 'prop_cs_cardbox_01',
    PackageCount = 10,
    Start = {
        returnRadius = 10.0,
        startZone = vector3(-2115.48, 3247.78, 32.81),
        startRadius = 2.5,
        vehicleSpawn = vector4(-2127.0608, 3247.0454, 32.4294, 59.9595),
        rearOffset = vector3(0.0, -4.2, 0.0),
        vehicleReturn = vector3(-2120.22, 3243.35, 32.81)
    },
    Destinations = {
        {
            id = 'lsia',
            label = 'LSIA',
            dropZone = vector3(-1069.6947, -2384.4204, 13.9452),
            npcPos = vector4(-1067.1592, -2381.3513, 13.9990, 154.0822),
            dropRadius = 5.5,
            reward = 200,
            trailerSpawn = vector4(-1116.20, -2968.90, 13.95, 330.0)
        },
        {
            id = 'docks',
            label = 'Los Santos Docks',
            dropZone = vector3(1206.74, -3230.51, 5.90),
            npcPos = vector4(1208.11, -3229.01, 5.90, 180.0),
            dropRadius = 5.5,
            reward = 250,
            trailerSpawn = vector4(1214.80, -3227.40, 5.90, 90.0)
        }
    },
    Tanker = {
        detachTime = 3500,
        attachRadius = 8.0,
        rearOffset = vector3(0.0, -4.2, 0.0)
    },
    Text = {
        startPrompt = 'Zahájit transport',
        unloadPrompt = 'Vyložit náklad',
        deliverPrompt = 'Předat náklad',
        started = 'Transport zahájen',
        unloadOk = 'Náklad vyložen',
        deliverOk = 'Náklad předán',
        notCarrying = 'Neneseš náklad',
        alreadyRun = 'Transport už probíhá',
        returnBlip = 'Návrat na základnu',
        returnPrompt = 'Vrátit vozidlo na základnu',
        returnInfo = 'Úkol splněn. Vrať se na základnu.',
        returnOk = 'Transport dokončen. Odměna připsána.',
        needMissionVeh = 'Musíš vrátit to samé vozidlo',
        leftInfo = 'Zbývá předat: ',
        assigned = 'Destinace: ',
        tankerDetach = 'Odpojit cisternu',
        tankerAttach = 'Připojit cisternu',
        tankerAttached = 'Cisterna připojena',
        tankerDetached = 'Cisterna odpojena',
        cancelPrompt = 'Zrušit transport',
        spawnBusy = 'Spawn je obsazený'
    }
}

Config.AirTransport = {
    city = {
        center = vector3(-75.0, -818.0, 30.0),
        radius = 1800.0,
        minHAG = 160.0,
        warnEvery = 1200,
        debug = false,
        debugHeight = 260.0
    },
    HeliModel = 'cargobob',
    CargoModel = 'prop_mil_crate_01',
    PayAccount = 'money',
    Start = {
        startZone = vector3(-1852.7551, 2793.0601, 32.806),
        startRadius = 2.5,
        heliSpawn = vector4(-1859.6525, 2795.0725, 32.8064, 334.8156),
        heliSpawn2 = vector4(-1877.1963, 2805.1648, 32.8065, 329.4332),
        vehicleReturn = vector3(-1859.6525, 2795.0725, 32.8064),
        returnRadius = 12.0
    },
    Destinations = {
        {
            id = 'air_carrier_pad',
            label = 'USS Luxington Carrier',
            pickupZone = vector3(-3255.6250, 3967.0933, 15.2623),
            --pickupZone = vector3(-1851.9052, 2813.7986, 32.8064),
            dropZone = vector3(3099.5745, -4744.2046, 15.2626),
            dropRadius = 8.0,
            reward = 200
        }
    },
    Attach = {
        heightMax = 8.0,
        radius = 6.0
    },
    Text = {
        startPrompt = 'Zahájit letecký transport',
        cancelPrompt = 'Zrušit letecký transport',
        attachHint = 'Přibliž se k nákladu a zvedni ho hákem (E)',
        detachHint = 'Leť nad cílovou zónu a stiskni E pro odpojení',
        routePick = 'Vydej se k vyzvednutí nákladu',
        routeDrop = 'Doruč náklad do cíle',
        returnBlip = 'Návrat na základnu',
        returnPrompt = 'Vrátit vrtulník na základnu',
        returnInfo = 'Úkol splněn. Vrať se na základnu.',
        returnOk = 'Transport dokončen. Odměna připsána.',
        alreadyRun = 'Letecký transport už probíhá',
        helipadBusy = 'Helipad je obsazený',
        spawnedAtAlt = 'Primární helipad byl obsazen, vrtulník je na záložním',
        lowCity = 'Varování: letíš nízko nad městem!'
    },
    Blip = {
        sprite = 64,
        color = 46
    }
}
