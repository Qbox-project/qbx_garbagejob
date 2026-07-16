local config = require 'config.server'
local sharedConfig = require 'config.shared'
local routes = {}
local activeTrucks = {}
local vehicleSpawns = {}
local MINIMUM_TIME_PER_BAG = 4000

---@param player table
---@return boolean
local function isGarbageWorker(player)
    return player.PlayerData.job and player.PlayerData.job.name == 'garbage'
end

---@param source number
---@param coords vector3
---@param maxDistance number
---@return boolean
local function isNear(source, coords, maxDistance)
    local ped = GetPlayerPed(source)
    return ped > 0 and #(GetEntityCoords(ped) - coords) <= maxDistance
end

---@param player table
---@return boolean
local function canPay(player)
    return player.PlayerData.money.bank >= sharedConfig.truckPrice
end

---@param citizenId string
---@return table?
local function getActiveTruck(citizenId)
    local truck = activeTrucks[citizenId]
    if truck and DoesEntityExist(truck.entity) then return truck end
end

---@param route table
---@return integer
local function calculateStopPay(route)
    local total = 0
    local bags = route.stops[route.currentStop].bags
    for _ = 1, bags do
        total += math.random(config.bagLowerWorth, config.bagUpperWorth)
    end
    return total
end

lib.callback.register('garbagejob:server:newShift', function(source)
    local player = exports.qbx_core:GetPlayer(source)
    if not player or not isGarbageWorker(player) then return false end
    if not isNear(source, sharedConfig.locations.paycheck.coords, 5.0) then return false end

    local citizenId = player.PlayerData.citizenid
    local route = routes[citizenId]
    local truck = getActiveTruck(citizenId)
    if activeTrucks[citizenId] and not truck then
        activeTrucks[citizenId] = nil
    end

    if route then
        if truck then return false end
        local current = route.stops[route.currentStop]
        return true, current.stop, current.bags, #route.stops
    end

    if not truck and not canPay(player) then
        exports.qbx_core:Notify(source, locale('error.not_enough', sharedConfig.truckPrice), 'error')
        return false
    end

    local maxStops = math.random(config.minStops, #sharedConfig.locations.trashcan)
    local allStops = {}
    for _ = 1, maxStops do
        allStops[#allStops + 1] = {
            stop = math.random(#sharedConfig.locations.trashcan),
            bags = math.random(config.minBagsPerStop, config.maxBagsPerStop),
        }
    end

    routes[citizenId] = {
        stops = allStops,
        currentStop = 1,
        actualPay = 0,
        stopsCompleted = 0,
        totalNumberOfStops = #allStops,
        availableAt = GetGameTimer() + allStops[1].bags * MINIMUM_TIME_PER_BAG,
    }

    exports.qbx_core:Notify(source, locale('info.stops_left', #allStops), 'info')
    return true, allStops[1].stop, allStops[1].bags, #allStops
end)

lib.callback.register('garbagejob:server:nextStop', function(source)
    local player = exports.qbx_core:GetPlayer(source)
    if not player or not isGarbageWorker(player) then return false, 0, 0 end

    local citizenId = player.PlayerData.citizenid
    local route = routes[citizenId]
    local truck = getActiveTruck(citizenId)
    if not route or not truck or route.completed then return false, 0, 0 end
    if GetGameTimer() < route.availableAt then return false, 0, 0 end

    local current = route.stops[route.currentStop]
    local stopCoords = sharedConfig.locations.trashcan[current.stop].coords.xyz
    if not isNear(source, stopCoords, 20.0) then
        exports.qbx_core:Notify(source, locale('error.too_far'), 'error')
        return false, 0, 0
    end
    if #(GetEntityCoords(truck.entity) - stopCoords) > 30.0 then
        exports.qbx_core:Notify(source, locale('error.no_truck'), 'error')
        return false, 0, 0
    end

    route.actualPay = math.ceil(route.actualPay + calculateStopPay(route))
    route.stopsCompleted += 1

    if config.giveItemReward and math.random(100) >= config.itemRewardChance then
        player.Functions.AddItem(config.itemRewardName, 1, false)
        exports.qbx_core:Notify(source, locale('info.found_crypto'))
    end

    if route.currentStop >= #route.stops then
        route.completed = true
        return false, current.stop, 0
    end

    route.currentStop += 1
    local nextStop = route.stops[route.currentStop]
    route.availableAt = GetGameTimer() + nextStop.bags * MINIMUM_TIME_PER_BAG
    exports.qbx_core:Notify(source, locale('info.stops_left', #route.stops - route.stopsCompleted), 'info')
    return true, nextStop.stop, nextStop.bags
end)

---@param spawnIndex any
---@return vector4?
local function getSpawnPoint(spawnIndex)
    if type(spawnIndex) ~= 'number' or spawnIndex % 1 ~= 0 then return end
    return sharedConfig.locations.vehicle.coords[spawnIndex]
end

lib.callback.register('garbagejob:server:spawnVehicle', function(source, spawnIndex)
    local player = exports.qbx_core:GetPlayer(source)
    if not player or not isGarbageWorker(player) then return end
    if not isNear(source, sharedConfig.locations.paycheck.coords, 5.0) then return end

    local citizenId = player.PlayerData.citizenid
    if not routes[citizenId] or getActiveTruck(citizenId) or vehicleSpawns[citizenId] then return end

    local spawnCoords = getSpawnPoint(spawnIndex)
    if not spawnCoords then return end
    if lib.getClosestVehicle(spawnCoords.xyz, 2.5, false) then return end

    vehicleSpawns[citizenId] = true
    if not player.Functions.RemoveMoney('bank', sharedConfig.truckPrice, 'garbage-deposit') then
        vehicleSpawns[citizenId] = nil
        exports.qbx_core:Notify(source, locale('error.not_enough', sharedConfig.truckPrice), 'error')
        return
    end

    local success, netId, vehicle = pcall(qbx.spawnVehicle, {
        spawnSource = spawnCoords,
        model = joaat(config.vehicle),
        warp = GetPlayerPed(source),
    })
    vehicleSpawns[citizenId] = nil

    if not success or not netId or not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then
        player.Functions.AddMoney('bank', sharedConfig.truckPrice, 'garbage-deposit-refund')
        return
    end

    local plate = 'GBGE' .. tostring(math.random(1000, 9999))
    SetVehicleNumberPlateText(vehicle, plate)
    exports.qbx_vehiclekeys:GiveKeys(source, vehicle)
    SetVehicleDoorsLocked(vehicle, 2)
    activeTrucks[citizenId] = {
        entity = vehicle,
        netId = netId,
        deposit = sharedConfig.truckPrice,
    }

    exports.qbx_core:Notify(source, locale('info.deposit_paid', sharedConfig.truckPrice), 'info')
    return netId
end)

lib.callback.register('garbagejob:server:payShift', function(source, continue)
    local player = exports.qbx_core:GetPlayer(source)
    if not player or not isGarbageWorker(player) then return false end
    if type(continue) ~= 'boolean' then return false end
    if not isNear(source, sharedConfig.locations.paycheck.coords, 5.0) then return false end

    local citizenId = player.PlayerData.citizenid
    local route = routes[citizenId]
    local truck = getActiveTruck(citizenId)
    if not route or not truck then
        exports.qbx_core:Notify(source, locale('error.never_clocked_on'), 'error')
        return false
    end
    if #(GetEntityCoords(truck.entity) - sharedConfig.locations.main.coords) > 40.0 then
        exports.qbx_core:Notify(source, locale('error.no_truck'), 'error')
        return false
    end
    if continue and not route.completed then return false end

    local depositPay = 0
    if route.completed and not continue then
        depositPay = truck.deposit
    elseif not route.completed then
        exports.qbx_core:Notify(
            source,
            locale('error.early_finish', route.stopsCompleted, route.totalNumberOfStops),
            'error'
        )
    end

    local totalToPay = depositPay + route.actualPay
    local payoutDeposit = depositPay > 0 and locale('info.payout_deposit', depositPay) or ''
    player.Functions.AddMoney('bank', totalToPay, 'garbage-payslip')
    exports.qbx_core:Notify(source, locale('success.pay_slip', totalToPay, payoutDeposit), 'success')
    routes[citizenId] = nil

    if not continue then
        activeTrucks[citizenId] = nil
        if not route.completed and DoesEntityExist(truck.entity) then
            DeleteEntity(truck.entity)
        end
    end
    return true
end)

lib.addCommand('cleargarbroutes', {
    help = 'Removes garbo routes for user (admin only)', -- luacheck: ignore
    params = {
        { name = 'id', help = 'Player ID', type = 'playerId' }
    },
    restricted = 'group.admin'
}, function(source, args)
    local player = exports.qbx_core:GetPlayer(args.id)
    if not player then return end

    local citizenId = player.PlayerData.citizenid
    local count = routes[citizenId] and 1 or 0
    routes[citizenId] = nil
    exports.qbx_core:Notify(source, locale('success.clear_routes', count), 'success')
end)
