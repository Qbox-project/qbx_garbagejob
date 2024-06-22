local config = require 'config.server'
local sharedConfig = require 'config.shared'
local routes = {}

local function canPay(player)
    return player.PlayerData.money.bank >= sharedConfig.truckPrice
end

lib.callback.register('garbagejob:server:newShift', function(source, continue)
    local player = exports.qbx_core:GetPlayer(source)
    if not player then return end

    local citizenId = player.PlayerData.citizenid
    local shouldContinue = false
    local nextStop = 0
    local totalNumberOfStops = 0
    local bagNum = 0

    if canPay(player) or continue then
        local maxStops = math.random(config.minStops, #sharedConfig.locations.trashcan)
        local allStops = {}

        for _ = 1, maxStops do
            local stop = math.random(#sharedConfig.locations.trashcan)
            local newBagAmount = math.random(config.minBagsPerStop, config.maxBagsPerStop)
            allStops[#allStops + 1] = {stop = stop, bags = newBagAmount}
        end

        routes[citizenId] = {
            stops = allStops,
            currentStop = 1,
            started = true,
            currentDistance = 0,
            depositPay = sharedConfig.truckPrice,
            actualPay = 0,
            stopsCompleted = 0,
            totalNumberOfStops = #allStops
        }

        nextStop = allStops[1].stop
        shouldContinue = true
        totalNumberOfStops = #allStops
        bagNum = allStops[1].bags

        -- Notify the player about the total number of stops left.
        exports.qbx_core:Notify(source, (locale('info.stops_left'):format(totalNumberOfStops)), 'info')
    else
        exports.qbx_core:Notify(source, (locale('error.not_enough'):format(sharedConfig.truckPrice)), 'error')
    end

    return shouldContinue, nextStop, bagNum, totalNumberOfStops
end)

lib.callback.register('garbagejob:server:nextStop', function(source, currentStop, currentStopNum, currLocation)
    local player = exports.qbx_core:GetPlayer(source)
    if not player then return end

    local citizenId = player.PlayerData.citizenid
    local currStopCoords = sharedConfig.locations.trashcan[currentStop].coords
    local distance = #(currLocation - currStopCoords.xyz)
    local newStop = 0
    local shouldContinue = false
    local newBagAmount = 0

    if config.giveItemReward and math.random(100) >= config.itemRewardChance then
        player.Functions.AddItem(config.itemRewardName, 1, false)
        exports.qbx_core:Notify(source, locale('info.found_crypto'))
    end

    if distance <= 20 then
        if currentStopNum >= #routes[citizenId].stops then
            routes[citizenId].stopsCompleted = tonumber(routes[citizenId].stopsCompleted) + 1
            newStop = currentStop
        else
            newStop = routes[citizenId].stops[currentStopNum+1].stop
            newBagAmount = routes[citizenId].stops[currentStopNum+1].bags
            shouldContinue = true
            local bagAmount = routes[citizenId].stops[currentStopNum].bags
            local totalNewPay = 0

            for _ = 1, bagAmount do
                totalNewPay += math.random(config.bagLowerWorth, config.bagUpperWorth)
            end

            routes[citizenId].actualPay = math.ceil(routes[citizenId].actualPay + totalNewPay)
            routes[citizenId].stopsCompleted = tonumber(routes[citizenId].stopsCompleted) + 1

            -- Notify the player about the number of stops left
            local stopsLeft = #routes[citizenId].stops - routes[citizenId].stopsCompleted
            exports.qbx_core:Notify(source, (locale('info.stops_left'):format(stopsLeft)), 'info')

        end
    else
        exports.qbx_core:Notify(source, locale('error.too_far'), 'error')
    end

    return shouldContinue, newStop, newBagAmount
end)

lib.callback.register('garbagejob:server:endShift', function(source)
    local player = exports.qbx_core:GetPlayer(source)
    if not player then return end

    local citizenId = player.PlayerData.citizenid
    return routes[citizenId]
end)

lib.callback.register('garbagejob:server:spawnVehicle', function(source, coords)
    local netId, veh = qbx.spawnVehicle({ spawnSource = coords, model = joaat(config.vehicle), warp = GetPlayerPed(source) })
    local plate = 'GBGE' .. tostring(math.random(1000, 9999))
    SetVehicleNumberPlateText(veh, plate)
    TriggerClientEvent('vehiclekeys:client:SetOwner', source, plate)
    SetVehicleDoorsLocked(veh, 2)
    local player = exports.qbx_core:GetPlayer(source)
    exports.qbx_core:Notify(source, (locale(player and not player.Functions.RemoveMoney('bank', sharedConfig.truckPrice, 'garbage-deposit') and 'error.not_enough' or 'info.deposit_paid'):format(sharedConfig.truckPrice)), 'error')

    return netId
end)

RegisterNetEvent('garbagejob:server:payShift', function(continue)
    local src = source
    local player = exports.qbx_core:GetPlayer(src)
    local citizenId = player.PlayerData.citizenid
    if routes[citizenId] then
        local depositPay = routes[citizenId].depositPay
        if tonumber(routes[citizenId].stopsCompleted) < tonumber(routes[citizenId].totalNumberOfStops) then
            depositPay = 0
            exports.qbx_core:Notify(src, (locale('error.early_finish'):format(routes[citizenId].stopsCompleted, routes[citizenId].totalNumberOfStops)), 'error')
        end
        if continue then
            depositPay = 0
        end
        local totalToPay = depositPay + routes[citizenId].actualPay
        local payoutDeposit = locale('info.payout_deposit', depositPay)
        if depositPay == 0 then
            payoutDeposit = ''
        end

        player.Functions.AddMoney('bank', totalToPay , 'garbage-payslip')
        exports.qbx_core:Notify(src, (locale('success.pay_slip'):format(totalToPay, payoutDeposit)), 'success')
        routes[citizenId] = nil
    else
        exports.qbx_core:Notify(source, locale('error.never_clocked_on'), 'error')
    end
end)

lib.addCommand('cleargarbroutes', {
    help = 'Removes garbo routes for user (admin only)', -- luacheck: ignore
    params = {
        { name = 'id', help = 'Player ID', type = 'playerId' }
    },
    restricted = 'group.admin'
},  function(source, args)
    local player = exports.qbx_core:GetPlayer(args.id)
    if not player then return end

    local citizenId = player.PlayerData.citizenid
    local count = 0
    for k in pairs(routes) do
        if k == citizenId then
            count += 1
        end
    end

    exports.qbx_core:Notify(source, (locale('success.clear_routes'):format(count)), 'success')
    routes[citizenId] = nil
end)
