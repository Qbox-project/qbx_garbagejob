local config = require 'config.client'
local sharedConfig = require 'config.shared'
local playerJob
local garbageVehicle
local hasBag = false
local currentStop = 0
local deliveryBlip
local amountOfBags = 0
local garbageObject
local endBlip
local garbageBlip
local canTakeBag = true
local currentStopNum = 0
local pZone
local garbageBinZone
local finished = false
local continueWorking = false
local garbText = false
local trucText = false
local pedsSpawned = false

local function setupClient()
    garbageVehicle = nil
    hasBag = false
    currentStop = 0
    deliveryBlip = nil
    amountOfBags = 0
    garbageObject = nil
    endBlip = nil
    currentStopNum = 0
    if playerJob.name == 'garbage' then
        garbageBlip = AddBlipForCoord(sharedConfig.locations.main.coords.x, sharedConfig.locations.main.coords.y, sharedConfig.locations.main.coords.z)
        SetBlipSprite(garbageBlip, 318)
        SetBlipDisplay(garbageBlip, 4)
        SetBlipScale(garbageBlip, 1.0)
        SetBlipAsShortRange(garbageBlip, true)
        SetBlipColour(garbageBlip, 39)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentSubstringPlayerName(sharedConfig.locations.main.label)
        EndTextCommandSetBlipName(garbageBlip)
    end
end

local function garbageMenu()
    local options = {}
    options[#options + 1] = {
        title = locale('menu.collect'),
        description = locale('menu.return_collect'),
        event = 'qb-garbagejob:client:RequestPaycheck'
    }
    if not garbageVehicle or finished then
        options[#options + 1] = {
            title = locale('menu.route'),
            description = locale('menu.request_route'),
            event = 'qb-garbagejob:client:RequestRoute'
        }
    end
    lib.registerContext({
        id = 'qb_gargabejob_mainMenu',
        title = locale('menu.header'),
        options = options
    })

    lib.showContext('qb_gargabejob_mainMenu')
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
    pZone:remove()
end

local function SetRouteBack()
    local depot = sharedConfig.locations.main.coords
    endBlip = AddBlipForCoord(depot.x, depot.y, depot.z)
    SetBlipSprite(endBlip, 1)
    SetBlipDisplay(endBlip, 2)
    SetBlipScale(endBlip, 1.0)
    SetBlipAsShortRange(endBlip, false)
    SetBlipColour(endBlip, 3)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(sharedConfig.locations.vehicle.label)
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
                lib.playAnim(cache.ped, 'missfbi4prepp1', '_bag_walk_garbage_man', 6.0, -6.0, -1, 49, 0, false, false, false)
            end
            Wait(1000)
        end
    end)
end

local function DeliverAnim()
    lib.playAnim(cache.ped, 'missfbi4prepp1', '_bag_throw_garbage_man', 8.0, 8.0, 1100, 48, 0.0, false, false, false)
    FreezeEntityPosition(cache.ped, true)
    SetEntityHeading(cache.ped, GetEntityHeading(garbageVehicle))
    canTakeBag = false
    SetTimeout(1250, function()
        DetachEntity(garbageObject, true, false)
        DeleteObject(garbageObject)
        lib.playAnim(cache.ped, 'missfbi4prepp1', 'exit', 8.0, 8.0, 1100, 48, 0.0, false, false, false)
        FreezeEntityPosition(cache.ped, false)
        garbageObject = nil
        canTakeBag = true
    end)
    if config.useTarget and hasBag then
        local CL = sharedConfig.locations.trashcan[currentStop]
        hasBag = false
        local pos = GetEntityCoords(cache.ped)
        exports.ox_target:removeEntity(NetworkGetNetworkIdFromEntity(garbageVehicle), 'garbage_deliver')
        if (amountOfBags - 1) <= 0 then
            local hasMoreStops, nextStop, newBagAmount = lib.callback.await('garbagejob:server:nextStop', false, currentStop, currentStopNum, pos)
            if hasMoreStops and nextStop ~= 0 then
                -- Here he puts your next location and you are not finished working yet.
                currentStop = nextStop
                currentStopNum = currentStopNum + 1
                amountOfBags = newBagAmount
                SetGarbageRoute()
                exports.qbx_core:Notify(locale('info.all_bags'))
                SetVehicleDoorShut(garbageVehicle, 5, false)
            else
                if hasMoreStops and nextStop == currentStop then
                    exports.qbx_core:Notify(locale('info.depot_issue'))
                    amountOfBags = 0
                else
                    -- You are done with work here.
                    exports.qbx_core:Notify(locale('info.done_working'))
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
                exports.qbx_core:Notify((locale('info.bags_left'):format(amountOfBags)))
            else
                exports.qbx_core:Notify((locale('info.bags_still'):format(amountOfBags)))
            end
            garbageBinZone = exports.ox_target:addSphereZone({
                coords = vec3(CL.coords.x, CL.coords.y, CL.coords.z),
                radius = 2.0,
                debug = config.debugPoly,
                options = {
                    {
                        label = locale('target.grab_garbage'),
                        icon = 'fa-solid fa-trash',
                        onSelect = TakeAnim,
                        distance = 2.0,
                        canInteract = function()
                            return not hasBag
                        end,
                    },
                },
            })
        end
    end
end

function TakeAnim()
    if lib.progressBar({
            duration = math.random(3000, 5000),
            label = locale('info.picking_bag'),
            useWhileDead = false,
            canCancel = true,
            disable = {
                car = true,
                move = true,
                combat = true,
                mouse = false
            },
            anim = {
                dict = 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@',
                clip = 'machinic_loop_mechandplayer'
            }
        }) then
        lib.playAnim(cache.ped, 'missfbi4prepp1', '_bag_walk_garbage_man', 6.0, -6.0, -1, 49, 0, false, false, false)
        lib.requestModel(`prop_cs_rub_binbag_01`, 10000)
        garbageObject = CreateObject(`prop_cs_rub_binbag_01`, 0, 0, 0, true, true, true)
        SetModelAsNoLongerNeeded(`prop_cs_rub_binbag_01`)
        AttachEntityToEntity(garbageObject, cache.ped, GetPedBoneIndex(cache.ped, 57005), 0.12, 0.0, -0.05, 220.0, 120.0, 0.0, true, true, false, true, 1, true)
        StopAnimTask(cache.ped, 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@', 'machinic_loop_mechandplayer', 1.0)
        AnimCheck()
        if config.useTarget and not hasBag then
            hasBag = true
            if garbageBinZone then
                exports.ox_target:removeZone(garbageBinZone)
                garbageBinZone = nil
            end
            local options = {
                {
                    name = 'garbage_deliver',
                    label = locale('target.dispose_garbage'),
                    icon = 'fa-solid fa-truck',
                    onSelect = DeliverAnim,
                    canInteract = function()
                        return hasBag
                    end,
                },
            }
            exports.ox_target:addEntity(NetworkGetNetworkIdFromEntity(garbageVehicle), options)
        end
    else
        StopAnimTask(cache.ped, 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@', 'machinic_loop_mechandplayer', 1.0)
        exports.qbx_core:Notify(locale('error.cancel'), 'error')
    end
end

local function runWorkLoop()
    local pos = GetEntityCoords(cache.ped)
    local DeliveryData = sharedConfig.locations.trashcan[currentStop]
    local Distance = #(pos - vec3(DeliveryData.coords.x, DeliveryData.coords.y, DeliveryData.coords.z))
    if Distance < 15 or hasBag then
        if not hasBag and canTakeBag then
            if Distance < 1.5 then
                if not garbText then
                    garbText = true
                    lib.showTextUI(locale('info.grab_garbage'))
                end
                if IsControlJustPressed(0, 51) then
                    hasBag = true
                    lib.hideTextUI()
                    TakeAnim()
                end
            elseif Distance < 10 then
                if garbText then
                    garbText = false
                    lib.hideTextUI()
                end
            end
        else
            if DoesEntityExist(garbageVehicle) then
                local Coords = GetOffsetFromEntityInWorldCoords(garbageVehicle, 0.0, -4.5, 0.0)
                local TruckDist = #(pos - Coords)

                if TruckDist < 2 then
                    if not trucText then
                        trucText = true
                        lib.showTextUI(locale('info.dispose_garbage'))
                    end
                    if IsControlJustPressed(0, 51) and hasBag then
                        StopAnimTask(cache.ped, 'missfbi4prepp1', '_bag_walk_garbage_man', 1.0)
                        DeliverAnim()
                        if lib.progressBar({
                                duration = 2000,
                                label = locale('info.progressbar'),
                                useWhileDead = false,
                                canCancel = true,
                                disable = {
                                    car = true,
                                    move = true,
                                    combat = true,
                                    mouse = false
                                }
                            }) then
                            hasBag = false
                            canTakeBag = false
                            DetachEntity(garbageObject, true, false)
                            DeleteObject(garbageObject)
                            FreezeEntityPosition(cache.ped, false)
                            garbageObject = nil
                            canTakeBag = true
                            -- Looks if you have delivered all bags
                            if (amountOfBags - 1) <= 0 then
                                local hasMoreStops, nextStop, newBagAmount = lib.callback.await(
                                'garbagejob:server:nextStop', false, currentStop, currentStopNum, pos)
                                if hasMoreStops and nextStop ~= 0 then
                                    -- Here he puts your next location and you are not finished working yet.
                                    currentStop = nextStop
                                    currentStopNum = currentStopNum + 1
                                    amountOfBags = newBagAmount
                                    SetGarbageRoute()
                                    exports.qbx_core:Notify(locale('info.all_bags'))
                                    SetVehicleDoorShut(garbageVehicle, 5, false)
                                else
                                    if hasMoreStops and nextStop == currentStop then
                                        exports.qbx_core:Notify(locale('info.depot_issue'))
                                        amountOfBags = 0
                                    else
                                        -- You are done with work here.
                                        exports.qbx_core:Notify(locale('info.done_working'))
                                        SetVehicleDoorShut(garbageVehicle, 5, false)
                                        RemoveBlip(deliveryBlip)
                                        SetRouteBack()
                                        amountOfBags = 0
                                    end
                                end
                                hasBag = false
                            else
                                -- You haven't delivered all bags here
                                amountOfBags = amountOfBags - 1
                                if amountOfBags > 1 then
                                    exports.qbx_core:Notify((locale('info.bags_left'):format(amountOfBags)))
                                else
                                    exports.qbx_core:Notify((locale('info.bags_still'):format(amountOfBags)))
                                end
                                hasBag = false
                            end

                            Wait(1500)
                            if trucText then
                                lib.hideTextUI()
                                trucText = false
                            end
                        else
                            exports.qbx_core:Notify(locale('error.cancel'), 'error')
                        end
                    end
                end
            else
                exports.qbx_core:Notify(locale('error.no_truck'), 'error')
                hasBag = false
            end
        end
    end
end

local function CreateZone(x, y, z)
    pZone = lib.zones.sphere({
        coords = vec3(x, y, z),
        radius = 15,
        debug = config.debugPoly,
        onEnter = function()
            SetVehicleDoorOpen(garbageVehicle,5,false,false)
        end,
        inside = function()
            if not config.useTarget then
                runWorkLoop()
            end
        end,
        onExit = function()
            if not config.useTarget then
                lib.hideTextUI()
            end
            SetVehicleDoorShut(garbageVehicle, 5, false)
        end,
    })
end

function SetGarbageRoute()
    local CL = sharedConfig.locations.trashcan[currentStop]
    if deliveryBlip then
        RemoveBlip(deliveryBlip)
    end
    deliveryBlip = AddBlipForCoord(CL.coords.x, CL.coords.y, CL.coords.z)
    SetBlipSprite(deliveryBlip, 1)
    SetBlipDisplay(deliveryBlip, 2)
    SetBlipScale(deliveryBlip, 1.0)
    SetBlipAsShortRange(deliveryBlip, false)
    SetBlipColour(deliveryBlip, 27)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(sharedConfig.locations.trashcan[currentStop].name)
    EndTextCommandSetBlipName(deliveryBlip)
    SetBlipRoute(deliveryBlip, true)
    finished = false
    if config.useTarget then
        if not hasBag then
            garbageBinZone = exports.ox_target:addSphereZone({
                coords = vec3(CL.coords.x, CL.coords.y, CL.coords.z),
                radius = 2.0,
                debug = config.debugPoly,
                options = {
                    {
                        label = locale('target.grab_garbage'),
                        icon = 'fa-solid fa-trash',
                        onSelect = TakeAnim,
                        canInteract = function()
                            return not hasBag
                        end,
                        distance = 2.0,
                    },
                },
            })
        end
    end
    if pZone then
        DeleteZone()
        Wait(500)
        CreateZone(CL.coords.x, CL.coords.y, CL.coords.z)
    else
        CreateZone(CL.coords.x, CL.coords.y, CL.coords.z)
    end
end

local function spawnPeds()
    if not config.peds or not next(config.peds) or pedsSpawned then return end
    for i = 1, #config.peds do
        local current = config.peds[i]
        current.model = type(current.model) == 'string' and joaat(current.model) or current.model

        lib.requestModel(current.model, 5000)
        local ped = CreatePed(0, current.model, current.coords.x, current.coords.y, current.coords.z, current.coords.w, false, false)
        SetModelAsNoLongerNeeded(current.model)
        FreezeEntityPosition(ped, true)
        SetEntityInvincible(ped, true)
        SetBlockingOfNonTemporaryEvents(ped, true)
        SetModelAsNoLongerNeeded(current.model)
        current.pedHandle = ped

        if config.useTarget then
            exports.ox_target:addLocalEntity(ped, {
                {
                    name = 'garbage_ped',
                    label = locale('target.talk'),
                    icon = 'fa-solid fa-recycle',
                    groups = 'garbage',
                    onSelect = garbageMenu,
                }
            })
        else
            lib.zones.box({
                coords = vec3(current.coords.x, current.coords.y, current.coords.z+0.5),
                size = vec3(3.0, 3.0, 2.0),
                rotation = current.coords.w,
                debug = config.debugPoly,
                inside = function()
                    if IsControlJustPressed(0, 38) then
                        garbageMenu()
                    end
                end,
                onEnter = function()
                    lib.showTextUI(locale('info.talk'))
                end,
                onExit = function()
                    lib.hideTextUI()
                end,
            })
        end
    end
    pedsSpawned = true
end

local function deletePeds()
    if not config.peds or not next(config.peds) or not pedsSpawned then return end
    for i = 1, #config.peds do
        local current = config.peds[i]
        if current.pedHandle then
            if config.useTarget then
                exports.ox_target:removeLocalEntity(current.pedHandle, 'garbage_ped')
            end
            DeletePed(current.pedHandle)
        end
    end
end

AddEventHandler('qb-garbagejob:client:RequestRoute', function()
    if garbageVehicle then
        continueWorking = true
        TriggerServerEvent('garbagejob:server:payShift', continueWorking)
    end

    local shouldContinue, firstStop, totalBags = lib.callback.await('garbagejob:server:newShift', false, continueWorking)
    if shouldContinue then
        if not garbageVehicle then
            local occupied = false
            for _, v in pairs(sharedConfig.locations.vehicle.coords) do
                if not IsAnyVehicleNearPoint(v.x,v.y,v.z, 2.5) then
                    local netId = lib.callback.await('garbagejob:server:spawnVehicle', false, v)

                    local veh = lib.waitFor(function()
                        if NetworkDoesEntityExistWithNetworkId(netId) then
                            return NetToVeh(netId)
                        end
                    end, 'Failed to spawn truck', 3000)

                    if veh == 0 then
                        lib.notify({ description = 'Failed to spawn truck', type = 'error' })
                        return
                    end

                    garbageVehicle = veh
                    SetVehicleFuelLevel(veh, 100.0)
                    SetVehicleFixed(veh)
                    currentStop = firstStop
                    currentStopNum = 1
                    amountOfBags = totalBags
                    SetGarbageRoute()
                    exports.qbx_core:Notify(locale('info.started'))
                    return
                else
                    occupied = true
                end
            end
            if occupied then
                exports.qbx_core:Notify(locale('error.all_occupied'))
            end
        end
        currentStop = firstStop
        currentStopNum = 1
        amountOfBags = totalBags
        SetGarbageRoute()
    else
        exports.qbx_core:Notify((locale('info.not_enough'):format(sharedConfig.truckPrice)))
    end
end)

AddEventHandler('qb-garbagejob:client:RequestPaycheck', function()
    if garbageVehicle then
        BringBackCar()
        exports.qbx_core:Notify(locale('info.truck_returned'))
    end
    TriggerServerEvent('garbagejob:server:payShift')
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