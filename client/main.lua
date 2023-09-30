local playerJob = nil
local garbageVehicle = nil
local hasBag = false
local currentStop = 0
local deliveryBlip = nil
local amountOfBags = 0
local garbageObject = nil
local endBlip = nil
local garbageBlip = nil
local canTakeBag = true
local currentStopNum = 0
local PZone = nil
local listen = false
local finished = false
local continueworking = false

-- Handlers

local function setupClient()
    garbageVehicle = nil
    hasBag = false
    currentStop = 0
    deliveryBlip = nil
    amountOfBags = 0
    garbageObject = nil
    endBlip = nil
    currentStopNum = 0
    if playerJob.name == "garbage" then
        garbageBlip = AddBlipForCoord(Config.Locations.main.coords.x, Config.Locations.main.coords.y, Config.Locations.main.coords.z)
        SetBlipSprite(garbageBlip, 318)
        SetBlipDisplay(garbageBlip, 4)
        SetBlipScale(garbageBlip, 1.0)
        SetBlipAsShortRange(garbageBlip, true)
        SetBlipColour(garbageBlip, 39)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentSubstringPlayerName(Config.Locations.main.label)
        EndTextCommandSetBlipName(garbageBlip)
    end
end

-- Functions

local function LoadAnimation(dict)
    RequestAnimDict(dict)
    while not HasAnimDictLoaded(dict) do Wait(10) end
end

local function BringBackCar()
    DeleteVehicle(garbageVehicle)
    if endBlip then
        RemoveBlip(endBlip)
    end
    if deliveryBlip then
        RemoveBlip(deliveryBlip)
    end
    garbageVehicle = nil
    hasBag = false
    currentStop = 0
    deliveryBlip = nil
    amountOfBags = 0
    garbageObject = nil
    endBlip = nil
    currentStopNum = 0
end

local function DeleteZone()
    listen = false
    PZone:destroy()
end

local function SetRouteBack()
    local depot = Config.Locations.main.coords
    endBlip = AddBlipForCoord(depot.x, depot.y, depot.z)
    SetBlipSprite(endBlip, 1)
    SetBlipDisplay(endBlip, 2)
    SetBlipScale(endBlip, 1.0)
    SetBlipAsShortRange(endBlip, false)
    SetBlipColour(endBlip, 3)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentSubstringPlayerName(Config.Locations.vehicle.label)
    EndTextCommandSetBlipName(endBlip)
    SetBlipRoute(endBlip, true)
    DeleteZone()
    finished = true
end

local function AnimCheck()
    CreateThread(function()
        while hasBag and not IsEntityPlayingAnim(cache.ped, 'missfbi4prepp1', '_bag_throw_garbage_man',3) do
            if not IsEntityPlayingAnim(cache.ped, 'missfbi4prepp1', '_bag_walk_garbage_man', 3) then
                ClearPedTasksImmediately(cache.ped)
                LoadAnimation('missfbi4prepp1')
                TaskPlayAnim(cache.ped, 'missfbi4prepp1', '_bag_walk_garbage_man', 6.0, -6.0, -1, 49, 0, false, false, false)
            end
            Wait(1000)
        end
    end)
end

local function DeliverAnim()
    LoadAnimation('missfbi4prepp1')
    TaskPlayAnim(cache.ped, 'missfbi4prepp1', '_bag_throw_garbage_man', 8.0, 8.0, 1100, 48, 0.0, false, false, false)
    FreezeEntityPosition(cache.ped, true)
    SetEntityHeading(cache.ped, GetEntityHeading(garbageVehicle))
    canTakeBag = false
    SetTimeout(1250, function()
        DetachEntity(garbageObject, true, false)
        DeleteObject(garbageObject)
        TaskPlayAnim(cache.ped, 'missfbi4prepp1', 'exit', 8.0, 8.0, 1100, 48, 0.0, false, false, false)
        FreezeEntityPosition(cache.ped, false)
        garbageObject = nil
        canTakeBag = true
    end)
    if Config.UseTarget and hasBag then
        local CL = Config.Locations.trashcan[currentStop]
        hasBag = false
        local pos = GetEntityCoords(cache.ped)
        exports['qb-target']:RemoveTargetEntity(garbageVehicle)
        if (amountOfBags - 1) <= 0 then
            local hasMoreStops, nextStop, newBagAmount = lib.callback.await('garbagejob:server:NextStop', false, currentStop, currentStopNum, pos)
            if hasMoreStops and nextStop ~= 0 then
                -- Here he puts your next location and you are not finished working yet.
                currentStop = nextStop
                currentStopNum = currentStopNum + 1
                amountOfBags = newBagAmount
                SetGarbageRoute()
                exports.qbx_core:Notify(Lang:t("info.all_bags"))
                SetVehicleDoorShut(garbageVehicle, 5, false)
            else
                if hasMoreStops and nextStop == currentStop then
                    exports.qbx_core:Notify(Lang:t("info.depot_issue"))
                    amountOfBags = 0
                else
                    -- You are done with work here.
                    exports.qbx_core:Notify(Lang:t("info.done_working"))
                    SetVehicleDoorShut(garbageVehicle, 5, false)
                    RemoveBlip(deliveryBlip)
                    SetRouteBack()
                    amountOfBags = 0
                end
            end
        else
            -- You haven't delivered all bags here
            amountOfBags = amountOfBags - 1
            if amountOfBags > 1 then
                exports.qbx_core:Notify(Lang:t("info.bags_left", { value = amountOfBags }))
            else
                exports.qbx_core:Notify(Lang:t("info.bags_still", { value = amountOfBags }))
            end
            exports['qb-target']:AddCircleZone('garbagebin', vector3(CL.coords.x, CL.coords.y, CL.coords.z), 2.0,{
                name = 'garbagebin', debugPoly = false, useZ=true}, {
                options = {{label = Lang:t("target.grab_garbage"),icon = 'fa-solid fa-trash', action = function() TakeAnim() end}},
                distance = 2.0
            })
        end
    end
end

function TakeAnim()
    exports.qbx_core:Progressbar("bag_pickup", Lang:t("info.picking_bag"), math.random(3000, 5000), false, true, {
        disableMovement = true,
        disableCarMovement = true,
        disableMouse = false,
        disableCombat = true,
    }, {
        animDict = "anim@amb@clubhouse@tutorial@bkr_tut_ig3@",
        anim = "machinic_loop_mechandplayer",
        flags = 16,
    }, {}, {}, function()
        LoadAnimation('missfbi4prepp1')
        TaskPlayAnim(cache.ped, 'missfbi4prepp1', '_bag_walk_garbage_man', 6.0, -6.0, -1, 49, 0, false, false, false)
        garbageObject = CreateObject(`prop_cs_rub_binbag_01`, 0, 0, 0, true, true, true)
        AttachEntityToEntity(garbageObject, cache.ped, GetPedBoneIndex(cache.ped, 57005), 0.12, 0.0, -0.05, 220.0, 120.0, 0.0, true, true, false, true, 1, true)
        StopAnimTask(cache.ped, "anim@amb@clubhouse@tutorial@bkr_tut_ig3@", "machinic_loop_mechandplayer", 1.0)
        AnimCheck()
        if Config.UseTarget and not hasBag then
            hasBag = true
            exports['qb-target']:RemoveZone("garbagebin")
            exports['qb-target']:AddTargetEntity(garbageVehicle, {
            options = {
                {label = Lang:t("target.dispose_garbage"),icon = 'fa-solid fa-truck',action = function() DeliverAnim() end,canInteract = function() if hasBag then return true end return false end, }
            },
            distance = 2.0
            })
        end
    end, function()
        StopAnimTask(cache.ped, "anim@amb@clubhouse@tutorial@bkr_tut_ig3@", "machinic_loop_mechandplayer", 1.0)
        exports.qbx_core:Notify(Lang:t("error.cancled"), "error")
    end)
end

local function RunWorkLoop()
    CreateThread(function()
        local GarbText = false
        while listen do
            local pos = GetEntityCoords(cache.ped)
            local DeliveryData = Config.Locations.trashcan[currentStop]
            local Distance = #(pos - vector3(DeliveryData.coords.x, DeliveryData.coords.y, DeliveryData.coords.z))
            if Distance < 15 or hasBag then

                if not hasBag and canTakeBag then
                    if Distance < 1.5 then
                        if not GarbText then
                            GarbText = true
                            lib.showTextUI(Lang:t("info.grab_garbage"))
                        end
                        if IsControlJustPressed(0, 51) then
                            hasBag = true
                            lib.hideTextUI()
                            TakeAnim()
                        end
                    elseif Distance < 10 then
                        if GarbText then
                            GarbText = false
                            lib.hideTextUI()
                        end
                    end
                else
                    if DoesEntityExist(garbageVehicle) then
                        local Coords = GetOffsetFromEntityInWorldCoords(garbageVehicle, 0.0, -4.5, 0.0)
                        local TruckDist = #(pos - Coords)
                        local TrucText = false

                        if TruckDist < 2 then
                            if not TrucText then
                                TrucText = true
                                lib.showTextUI(Lang:t("info.dispose_garbage"))
                            end
                            if IsControlJustPressed(0, 51) and hasBag then
                                StopAnimTask(cache.ped, 'missfbi4prepp1', '_bag_walk_garbage_man', 1.0)
                                DeliverAnim()
                                exports.qbx_core:Progressbar("deliverbag", Lang:t("info.progressbar"), 2000, false, true, {
                                        disableMovement = true,
                                        disableCarMovement = true,
                                        disableMouse = false,
                                        disableCombat = true,
                                    }, {}, {}, {}, function() -- Done
                                        hasBag = false
                                        canTakeBag = false
                                        DetachEntity(garbageObject, true, false)
                                        DeleteObject(garbageObject)
                                        FreezeEntityPosition(cache.ped, false)
                                        garbageObject = nil
                                        canTakeBag = true
                                        -- Looks if you have delivered all bags
                                        if (amountOfBags - 1) <= 0 then
                                            local hasMoreStops, nextStop, newBagAmount = lib.callback.await('garbagejob:server:NextStop', false, currentStop, currentStopNum, pos)
                                            if hasMoreStops and nextStop ~= 0 then
                                                -- Here he puts your next location and you are not finished working yet.
                                                currentStop = nextStop
                                                currentStopNum = currentStopNum + 1
                                                amountOfBags = newBagAmount
                                                SetGarbageRoute()
                                                exports.qbx_core:Notify(Lang:t("info.all_bags"))
                                                listen = false
                                                SetVehicleDoorShut(garbageVehicle, 5, false)
                                            else
                                                if hasMoreStops and nextStop == currentStop then
                                                    exports.qbx_core:Notify(Lang:t("info.depot_issue"))
                                                    amountOfBags = 0
                                                else
                                                    -- You are done with work here.
                                                    exports.qbx_core:Notify(Lang:t("info.done_working"))
                                                    SetVehicleDoorShut(garbageVehicle, 5, false)
                                                    RemoveBlip(deliveryBlip)
                                                    SetRouteBack()
                                                    amountOfBags = 0
                                                    listen = false
                                                end
                                            end
                                            hasBag = false
                                        else
                                            -- You haven't delivered all bags here
                                            amountOfBags = amountOfBags - 1
                                            if amountOfBags > 1 then
                                                exports.qbx_core:Notify(Lang:t("info.bags_left", { value = amountOfBags }))
                                            else
                                                exports.qbx_core:Notify(Lang:t("info.bags_still", { value = amountOfBags }))
                                            end
                                            hasBag = false
                                        end

                                        Wait(1500)
                                        if TrucText then
                                            lib.hideTextUI()
                                            TrucText = false
                                        end
                                    end, function() -- Cancel
                                    exports.qbx_core:Notify(Lang:t("error.cancled"), "error")
                                end)

                            end
                        end
                    else
                        exports.qbx_core:Notify(Lang:t("error.no_truck"), "error")
                        hasBag = false
                    end
                end
            end
            Wait(1)
        end
    end)
end

local function CreateZone(x, y, z)
    CreateThread(function()
        PZone = CircleZone:Create(vector3(x, y, z), 15.0, {
            name = "NewRouteWhoDis",
            debugPoly = false,
        })

        PZone:onPlayerInOut(function(isPointInside)
            if isPointInside then
                if not Config.UseTarget then
                    listen = true
                    RunWorkLoop()
                end
                SetVehicleDoorOpen(garbageVehicle,5,false,false)
            else
                if not Config.UseTarget then
                    lib.hideTextUI()
                    listen = false
                end
                SetVehicleDoorShut(garbageVehicle, 5, false)
            end
        end)
    end)
end

function SetGarbageRoute()
    local CL = Config.Locations.trashcan[currentStop]
    if deliveryBlip then
        RemoveBlip(deliveryBlip)
    end
    deliveryBlip = AddBlipForCoord(CL.coords.x, CL.coords.y, CL.coords.z)
    SetBlipSprite(deliveryBlip, 1)
    SetBlipDisplay(deliveryBlip, 2)
    SetBlipScale(deliveryBlip, 1.0)
    SetBlipAsShortRange(deliveryBlip, false)
    SetBlipColour(deliveryBlip, 27)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentSubstringPlayerName(Config.Locations.trashcan[currentStop].name)
    EndTextCommandSetBlipName(deliveryBlip)
    SetBlipRoute(deliveryBlip, true)
    finished = false
    if Config.UseTarget and not hasBag then
        exports['qb-target']:AddCircleZone('garbagebin', vector3(CL.coords.x, CL.coords.y, CL.coords.z), 2.0,{
            name = 'garbagebin', debugPoly = false, useZ=true }, {
            options = {{label = Lang:t("target.grab_garbage"), icon = 'fa-solid fa-trash', action = function() TakeAnim() end }},
            distance = 2.0
        })
    end
    if PZone then
        DeleteZone()
        Wait(500)
        CreateZone(CL.coords.x, CL.coords.y, CL.coords.z)
    else
        CreateZone(CL.coords.x, CL.coords.y, CL.coords.z)
    end
end

local ControlListen = false
local function Listen4Control()
    ControlListen = true
    CreateThread(function()
        while ControlListen do
            if IsControlJustReleased(0, 38) then
                TriggerEvent("qb-garbagejob:client:MainMenu")
            end
            Wait(1)
        end
    end)
end

local pedsSpawned = false
local function spawnPeds()
    if not Config.Peds or not next(Config.Peds) or pedsSpawned then return end
    for i = 1, #Config.Peds do
        local current = Config.Peds[i]
        current.model = type(current.model) == 'string' and joaat(current.model) or current.model
        RequestModel(current.model)
        while not HasModelLoaded(current.model) do
            Wait(0)
        end
        local ped = CreatePed(0, current.model, current.coords.x, current.coords.y, current.coords.z, current.coords.w, false, false)
        FreezeEntityPosition(ped, true)
        SetEntityInvincible(ped, true)
        SetBlockingOfNonTemporaryEvents(ped, true)
        current.pedHandle = ped

        if Config.UseTarget then
            exports['qb-target']:AddTargetEntity(ped, {
                options = {{type = "client", event = "qb-garbagejob:client:MainMenu", label = Lang:t("target.talk"), icon = 'fa-solid fa-recycle', job = "garbage",}},
                distance = 2.0
            })
        else
            local options = current.zoneOptions
            if options then
                local zone = BoxZone:Create(current.coords.xyz, options.length, options.width, {
                    name = "zone_cityhall_" .. ped,
                    heading = current.coords.w,
                    debugPoly = false
                })
                zone:onPlayerInOut(function(inside)
                    if LocalPlayer.state.isLoggedIn then
                        if inside then
                            lib.showTextUI(Lang:t("info.talk"))
                            Listen4Control()
                        else
                            ControlListen = false
                            lib.hideTextUI()
                        end
                    end
                end)
            end
        end
    end
    pedsSpawned = true
end

local function deletePeds()
    if not Config.Peds or not next(Config.Peds) or not pedsSpawned then return end
    for i = 1, #Config.Peds do
        local current = Config.Peds[i]
        if current.pedHandle then
            DeletePed(current.pedHandle)
        end
    end
end

-- Events

RegisterNetEvent('garbagejob:client:SetWaypointHome', function()
    SetNewWaypoint(Config.Locations.main.coords.x, Config.Locations.main.coords.y)
end)

RegisterNetEvent('qb-garbagejob:client:RequestRoute', function()
    if garbageVehicle then
        continueworking = true
        TriggerServerEvent('garbagejob:server:PayShift', continueworking)
    end

    local shouldContinue, firstStop, totalBags = lib.callback.await("garbagejob:server:NewShift", false, continueworking)
    if shouldContinue then
        if not garbageVehicle then
            local occupied = false
            for _, v in pairs(Config.Locations.vehicle.coords) do
                if not IsAnyVehicleNearPoint(v.x,v.y,v.z, 2.5) then
                    local netId = lib.callback.await('garbagejob:server:spawnVehicle', false, v)
                    Wait(300)
                    if not netId or netId == 0 or not NetworkDoesEntityExistWithNetworkId(netId) then
                        lib.notify({
                            description = 'Failed to spawn truck',
                            type = 'error'
                        })
                        return
                    end

                    local veh = NetToVeh(netId)
                    if veh == 0 then
                        lib.notify({
                            description = 'Failed to spawn truck',
                            type = 'error'
                        })
                        return
                    end

                    garbageVehicle = veh
                    SetVehicleFuelLevel(veh, 100.0)
                    SetVehicleFixed(veh)
                    currentStop = firstStop
                    currentStopNum = 1
                    amountOfBags = totalBags
                    SetGarbageRoute()
                    exports.qbx_core:Notify(Lang:t("info.started"))
                    return
                else
                    occupied = true
                end
            end
            if occupied then
                exports.qbx_core:Notify(Lang:t("error.all_occupied"))
            end
        end
        currentStop = firstStop
        currentStopNum = 1
        amountOfBags = totalBags
        SetGarbageRoute()
    else
        exports.qbx_core:Notify(Lang:t("info.not_enough", { value = Config.TruckPrice }))
    end
end)

RegisterNetEvent('qb-garbagejob:client:RequestPaycheck', function()
    if garbageVehicle then
        BringBackCar()
        exports.qbx_core:Notify(Lang:t("info.truck_returned"))
    end
    TriggerServerEvent('garbagejob:server:PayShift')
end)

RegisterNetEvent('qb-garbagejob:client:MainMenu', function()
        local MainMenu = {}
        MainMenu[#MainMenu+1] = {isMenuHeader = true,header = Lang:t("menu.header")}
        MainMenu[#MainMenu+1] = { header = Lang:t("menu.collect"),txt = Lang:t("menu.return_collect"),params = { event = 'qb-garbagejob:client:RequestPaycheck',}}
        if not garbageVehicle or finished then
            MainMenu[#MainMenu+1] = { header = Lang:t("menu.route"), txt = Lang:t("menu.request_route"), params = { event = 'qb-garbagejob:client:RequestRoute',}}
        end
    lib.registerContext({
        id = 'qb_gargabejob_mainMenu',
        title = Lang:t("menu.header"),
        options = MainMenu
    })

    lib.showContext('qb_gargabejob_mainMenu')
end)

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    playerJob = QBX.PlayerData.job
    setupClient()
    spawnPeds()
end)

RegisterNetEvent('QBCore:Client:OnJobUpdate', function(JobInfo)
    playerJob = JobInfo
    if garbageBlip then
        RemoveBlip(garbageBlip)
    end
    if endBlip then
        RemoveBlip(endBlip)
    end
    if deliveryBlip then
        RemoveBlip(deliveryBlip)
    end
    endBlip = nil
    deliveryBlip = nil
    setupClient()
    spawnPeds()
end)

AddEventHandler('onResourceStop', function(resource)
    if GetCurrentResourceName() == resource then
        if garbageObject then
            DeleteEntity(garbageObject)
            garbageObject = nil
        end
        deletePeds()
    end
end)

AddEventHandler('onResourceStart', function(resource)
    if GetCurrentResourceName() == resource then
        playerJob = QBX.PlayerData.job
        setupClient()
        spawnPeds()
    end
end)
