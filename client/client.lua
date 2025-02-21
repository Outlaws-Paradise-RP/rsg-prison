local RSGCore = exports['rsg-core']:GetCoreObject()

local jailtimeMinsRemaining = 0
local inJail = false
local inJailZone = false
local jailTime = 0
local Zones = {}

-----------------------------------------------------------------------------------

-- prompts
Citizen.CreateThread(function()
    for prison, v in pairs(Config.MenuLocations) do
        exports['rsg-core']:createPrompt(v.prompt, v.coords, RSGCore.Shared.Keybinds['J'], 'Open ' .. v.name, {
            type = 'client',
            event = 'rsg-prison:client:menu',
            args = {},
        })
        if v.showblip == true then
            local PrisonBlip = Citizen.InvokeNative(0x554D9D53F696D002, 1664425300, v.coords)
            SetBlipSprite(PrisonBlip, GetHashKey(Config.Blip.blipSprite), true)
            SetBlipScale(PrisonBlip, Config.Blip.blipScale)
            Citizen.InvokeNative(0x9CB1A1623062F402, PrisonBlip, Config.Blip.blipName)
        end
    end
end)

-- draw marker if set to true in config
CreateThread(function()
    while true do
        Wait(1)
        inRange = false
        local pos = GetEntityCoords(PlayerPedId())
        for prison, v in pairs(Config.MenuLocations) do
            if #(pos - v.coords) < Config.MarkerDistance then
                inRange = true
                if v.showmarker == true then
                    Citizen.InvokeNative(0x2A32FAA57B937173, 0x07DCE236, v.coords, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 1.0, 1.0, 255, 215, 0, 155, false, false, false, 1, false, false, false)
                end
            end
            if not inRange then
                Wait(2500)
            end
        end
    end
end)

-- Prison Zone
CreateThread(function()
    for k = 1, #Config.PrisonZone do
        Zones[k] = PolyZone:Create(Config.PrisonZone[k].zones,
        {
            name = Config.PrisonZone[k].name,
            minZ = Config.PrisonZone[k].minz,
            maxZ = Config.PrisonZone[k].maxz,
            debugPoly = false
        })

        Zones[k]:onPlayerInOut(function(isPointInside)
            if not isPointInside then
                inJailZone = false
                return
            end

            inJailZone = true
        end)
    end
end)

-- Prison Zone Loop
CreateThread(function()
    while true do
        local ped = PlayerPedId()
        local isJailed = 0
        local teleport = vector3(3368.31, -665.94, 46.29)

        if LocalPlayer.state['isLoggedIn'] then
            RSGCore.Functions.GetPlayerData(function(PlayerData)
                isJailed = PlayerData.metadata["injail"]
            end)
        end

        if isJailed <= 0 then goto continue end
        if inJailZone then goto continue end

        lib.notify({ title = '🚨', description = 'Returning you back to the Prison zone!', type = 'inform', duration = 5000 })

        Wait(3000)
        DoScreenFadeOut(1000)
        Wait(1000)
        SetEntityCoords(ped, teleport)
        Wait(1000)
        DoScreenFadeIn(1000)

        ::continue::

        Wait(10000)
    end
end)

-----------------------------------------------------------------------------------

RegisterNetEvent('rsg-prison:client:menu', function()
    lib.registerContext(
        {
            id = 'prison_menu',
            title = 'Prison Menu',
            position = 'top-right',
            options = {
                {
                    title = 'Prison Shop',
                    description = 'keep yourself alive',
                    icon = 'fas fa-shopping-basket',
                    event = 'rsg-prison:client:shop'
                },
                {
                    title = 'Post Office',
                    description = 'keep in touch with loved ones',
                    icon = 'far fa-envelope-open',
                    event = 'rsg-prison:client:telegrammenu'
                },
            }
        }
    )
    lib.showContext('prison_menu')
end)

RegisterNetEvent('rsg-prison:client:telegrammenu', function()
    lib.registerContext(
        {
            id = 'telegram_menu',
            title = 'Telegram Menu',
            position = 'top-right',
            menu = 'prison_menu',
            onBack = function() end,
            options = {
                {
                    title = 'Read Messages',
                    description = 'read your telegram messages',
                    icon = 'far fa-envelope-open',
                    event = 'rsg-telegram:client:ReadMessages'
                },
                {
                    title = 'Send Telegram',
                    description = 'send a telegram',
                    icon = 'far fa-envelope-open',
                    event = 'rsg-telegram:client:WriteMessagePostOffice'
                },
            }
        }
    )
    lib.showContext('telegram_menu')
end)

-----------------------------------------------------------------------------------

-- prison shop
RegisterNetEvent('rsg-prison:client:shop')
AddEventHandler('rsg-prison:client:shop', function()
    local ShopItems = {}
    ShopItems.label = "Prison Shop"
    ShopItems.items = Config.PrisonShop
    ShopItems.slots = #Config.PrisonShop
    TriggerServerEvent("inventory:server:OpenInventory", "shop", "PrisonShop_"..math.random(1, 99), ShopItems)
end)

-----------------------------------------------------------------------------------

RegisterNetEvent('RSGCore:Client:OnPlayerLoaded', function()
    RSGCore.Functions.GetPlayerData(function(PlayerData)
        if PlayerData.metadata["injail"] > 0 then
            TriggerEvent("rsg-prison:client:Enter", PlayerData.metadata["injail"])
        end
    end)
end)

AddEventHandler('onResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    Wait(100)
    if LocalPlayer.state['isLoggedIn'] then
        RSGCore.Functions.GetPlayerData(function(PlayerData)
            if PlayerData.metadata["injail"] > 0 then
                TriggerEvent("rsg-prison:client:Enter", PlayerData.metadata["injail"])
            end
        end)
    end
end)

RegisterNetEvent('RSGCore:Client:OnPlayerUnload', function()
    inJail = false
end)

-----------------------------------------------------------------------------------

-- sent to jail
RegisterNetEvent('rsg-prison:client:Enter', function(time)
    jailTime = time -- in mins
    local RandomStartPosition = Config.Locations.spawns[math.random(1, #Config.Locations.spawns)]
    SetEntityCoords(PlayerPedId(), RandomStartPosition.coords.x, RandomStartPosition.coords.y, RandomStartPosition.coords.z - 0.9, 0, 0, 0, false)
    SetEntityHeading(PlayerPedId(), RandomStartPosition.coords.w)
    Wait(500)
    TriggerServerEvent('rsg-prison:server:SaveJailItems')
    lib.notify({ title = '🚨', description = 'Your property has been seized', type = 'inform', duration = 5000 })
    TriggerEvent('rsg-prison:client:prisonclothes')
    TriggerServerEvent('rsg-prison:server:RemovePlayerJob')
    TriggerServerEvent('InteractSound_SV:PlayWithinDistance', 5, 'jail', 0.6)
    inJail = true
    handleJailtime()
end)

-----------------------------------------------------------------------------------

RegisterNetEvent("rsg-prison:client:prisonclothes") -- prison outfit event
AddEventHandler("rsg-prison:client:prisonclothes", function()
    local ped = PlayerPedId()
    Citizen.InvokeNative(0xDF631E4BCE1B1FC4, ped, 0x9925C067, true, true, true)
    Citizen.InvokeNative(0xDF631E4BCE1B1FC4, ped, 0x485EE834, true, true, true)
    Citizen.InvokeNative(0xDF631E4BCE1B1FC4, ped, 0x18729F39, true, true, true)
    Citizen.InvokeNative(0xDF631E4BCE1B1FC4, ped, 0x3107499B, true, true, true)
    Citizen.InvokeNative(0xDF631E4BCE1B1FC4, ped, 0x3C1A74CD, true, true, true)
    Citizen.InvokeNative(0xDF631E4BCE1B1FC4, ped, 0x3F1F01E5, true, true, true)
    Citizen.InvokeNative(0xDF631E4BCE1B1FC4, ped, 0x3F7F3587, true, true, true)
    Citizen.InvokeNative(0xDF631E4BCE1B1FC4, ped, 0x49C89D9B, true, true, true)
    Citizen.InvokeNative(0xDF631E4BCE1B1FC4, ped, 0x4A73515C, true, true, true)
    Citizen.InvokeNative(0xDF631E4BCE1B1FC4, ped, 0x514ADCEA, true, true, true)
    Citizen.InvokeNative(0xDF631E4BCE1B1FC4, ped, 0x5FC29285, true, true, true)
    Citizen.InvokeNative(0xDF631E4BCE1B1FC4, ped, 0x79D7DF96, true, true, true)
    Citizen.InvokeNative(0xDF631E4BCE1B1FC4, ped, 0x7A96FACA, true, true, true)
    Citizen.InvokeNative(0xDF631E4BCE1B1FC4, ped, 0x877A2CF7, true, true, true)
    Citizen.InvokeNative(0xDF631E4BCE1B1FC4, ped, 0x9B2C8B89, true, true, true)
    Citizen.InvokeNative(0xDF631E4BCE1B1FC4, ped, 0xA6D134C6, true, true, true)
    Citizen.InvokeNative(0xDF631E4BCE1B1FC4, ped, 0xE06D30CE, true, true, true)
    Citizen.InvokeNative(0xDF631E4BCE1B1FC4, ped, 0x662AC34, true, true, true)
    Citizen.InvokeNative(0xDF631E4BCE1B1FC4, ped, 0xAF14310B, true, true, true)
    Citizen.InvokeNative(0xDF631E4BCE1B1FC4, ped, 0x72E6EF74, true, true, true)
    Citizen.InvokeNative(0xDF631E4BCE1B1FC4, ped, 0xEABE0032, true, true, true)
    Citizen.InvokeNative(0xDF631E4BCE1B1FC4, ped, 0x2026C46D, true, true, true)
    Citizen.InvokeNative(0xDF631E4BCE1B1FC4, ped, 0xB6B6122D, true, true, true)
    Citizen.InvokeNative(0xDF631E4BCE1B1FC4, ped, 0xB9E2FA01, true, true, true)

    if IsPedMale(ped) then
        Citizen.InvokeNative(0xD3A7B003ED343FD9, ped, 0x5BA76CCF, true, true, true)
        Citizen.InvokeNative(0xD3A7B003ED343FD9, ped, 0x216612F0, true, true, true)
        Citizen.InvokeNative(0xD3A7B003ED343FD9, ped, 0x1CCEE58D, true, true, true)
    else
        Citizen.InvokeNative(0xD3A7B003ED343FD9, ped, 0x6AB27695, true, true, true)
        Citizen.InvokeNative(0xD3A7B003ED343FD9, ped, 0x75BC0CF5, true, true, true)
        Citizen.InvokeNative(0xD3A7B003ED343FD9, ped, 0x14683CDF, true, true, true)
    end
    RemoveAllPedWeapons(ped, true, true)
end)

-----------------------------------------------------------------------------------

-- jail timer
function handleJailtime()
    jailtimeMinsRemaining = jailTime
    Citizen.CreateThread(function()
        while jailtimeMinsRemaining > 0 do
            Wait(1000 * 60)
            jailtimeMinsRemaining = jailtimeMinsRemaining - 1
            if jailtimeMinsRemaining > 0 then
                if jailtimeMinsRemaining > 1 then
                    exports['rsg-core']:DrawText('Freedom in '..jailtimeMinsRemaining..' mins!', 'left')
                    TriggerServerEvent('rsg-prison:server:updateSentance', jailtimeMinsRemaining)
                else
                    exports['rsg-core']:DrawText('Getting ready for release!', 'left')
                    TriggerServerEvent('rsg-prison:server:updateSentance', jailtimeMinsRemaining)
                end
            else
                exports['rsg-core']:HideText()
                TriggerEvent('rsg-prison:client:freedom')
            end
        end
    end)
end

-----------------------------------------------------------------------------------

-- released from jail
RegisterNetEvent('rsg-prison:client:freedom', function()
    TriggerServerEvent('rsg-prison:server:FreePlayer')
    TriggerServerEvent('rsg-prison:server:GiveJailItems')
    Wait(500)
    DoScreenFadeOut(1000)
    Wait(3000)
    SetEntityCoords(PlayerPedId(), Config.Locations["outside"].coords.x, Config.Locations["outside"].coords.y, Config.Locations["outside"].coords.z, 0, 0, 0, false)
    SetEntityHeading(PlayerPedId(), Config.Locations["outside"].coords.w)
    local currentHealth = GetEntityHealth(PlayerPedId())
    local maxStamina = Citizen.InvokeNative(0xCB42AFE2B613EE55, PlayerPedId(), Citizen.ResultAsFloat())
    local currentStamina = Citizen.InvokeNative(0x775A1CA7893AA8B5, PlayerPedId(), Citizen.ResultAsFloat()) / maxStamina * 100
    TriggerServerEvent("rsg-appearance:LoadSkin")
    Wait(3000)
    SetEntityHealth(PlayerPedId(), currentHealth )
    Citizen.InvokeNative(0xC3D4B754C0E86B9E, PlayerPedId(), currentStamina)
    DoScreenFadeIn(1000)
    lib.notify({ title = '🚨', description = 'You\'re free from prison, good luck', type = 'inform', duration = 5000 })
    Wait(5000)
    lib.notify({ title = '🚨', description = 'You received your property back', type = 'inform', duration = 5000 })
    inJail = false
end)

-----------------------------------------------------------------------------------
