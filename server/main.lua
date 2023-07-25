local QBCore = exports['qbx-core']:GetCoreObject()
local routes = {}

local function canPay(player)
    return player.PlayerData.money.bank >= Config.TruckPrice
end

lib.callback.register("garbagejob:server:NewShift", function(source, continue)
    local player = QBCore.Functions.GetPlayer(source)
    if not player then return end

    local citizenId = player.PlayerData.citizenid
    local shouldContinue = false
    local nextStop = 0
    local totalNumberOfStops = 0
    local bagNum = 0

    if canPay(player) or continue then
        local maxStops = math.random(Config.MinStops, #Config.Locations.trashcan)
        local allStops = {}

        for _ = 1, maxStops do
            local stop = math.random(#Config.Locations.trashcan)
            local newBagAmount = math.random(Config.MinBagsPerStop, Config.MaxBagsPerStop)
            allStops[#allStops + 1] = {stop = stop, bags = newBagAmount}
        end

        routes[citizenId] = {
            stops = allStops,
            currentStop = 1,
            started = true,
            currentDistance = 0,
            depositPay = Config.TruckPrice,
            actualPay = 0,
            stopsCompleted = 0,
            totalNumberOfStops = #allStops
        }

        nextStop = allStops[1].stop
        shouldContinue = true
        totalNumberOfStops = #allStops
        bagNum = allStops[1].bags
    else
        TriggerClientEvent('QBCore:Notify', source, Lang:t("error.not_enough", {value = Config.TruckPrice}), "error")
    end

    return shouldContinue, nextStop, bagNum, totalNumberOfStops
end)

lib.callback.register("garbagejob:server:NextStop", function(source, currentStop, currentStopNum, currLocation)
    local player = QBCore.Functions.GetPlayer(source)
    if not player then return end

    local citizenId = player.PlayerData.citizenid
    local currStopCoords = Config.Locations.trashcan[currentStop].coords
    local distance = #(currLocation - currStopCoords.xyz)
    local newStop = 0
    local shouldContinue = false
    local newBagAmount = 0

    if math.random(100) >= Config.CryptoStickChance and Config.GiveCryptoStick then
        player.Functions.AddItem("cryptostick", 1, false)
        TriggerClientEvent('QBCore:Notify', source, Lang:t("info.found_crypto"))
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
                totalNewPay += math.random(Config.BagLowerWorth, Config.BagUpperWorth)
            end

            routes[citizenId].actualPay = math.ceil(routes[citizenId].actualPay + totalNewPay)
            routes[citizenId].stopsCompleted = tonumber(routes[citizenId].stopsCompleted) + 1
        end
    else
        TriggerClientEvent('QBCore:Notify', source, Lang:t("error.too_far"), "error")
    end

    return shouldContinue, newStop, newBagAmount
end)

lib.callback.register('garbagejob:server:EndShift', function(source)
    local player = QBCore.Functions.GetPlayer(source)
    if not player then return end

    local citizenId = player.PlayerData.citizenid
    return routes[citizenId]
end)

lib.callback.register('garbagejob:server:spawnVehicle', function(source, coords)
    local netId = QBCore.Functions.CreateVehicle(source, joaat(Config.Vehicle), coords, false)
    if not netId or netId == 0 then return end
    local veh = NetworkGetEntityFromNetworkId(netId)
    if not veh or veh == 0 then return end

    local plate = "GBGE" .. tostring(math.random(1000, 9999))
    SetVehicleNumberPlateText(veh, plate)
    TriggerClientEvent('vehiclekeys:client:SetOwner', source, plate)
    SetVehicleDoorsLocked(veh, 2)
    local player = QBCore.Functions.GetPlayer(source)
    TriggerClientEvent('QBCore:Notify', source, Lang:t(player and not player.Functions.RemoveMoney("bank", Config.TruckPrice, "garbage-deposit") and "error.not_enough" or "info.deposit_paid", {value = Config.TruckPrice}), "error")

    return netId
end)

RegisterNetEvent('garbagejob:server:PayShift', function(continue)
    local src = source
    local player = QBCore.Functions.GetPlayer(src)
    local citizenId = player.PlayerData.citizenid
    if routes[citizenId] then
        local depositPay = routes[citizenId].depositPay
        if tonumber(routes[citizenId].stopsCompleted) < tonumber(routes[citizenId].totalNumberOfStops) then
            depositPay = 0
            TriggerClientEvent('QBCore:Notify', src, Lang:t("error.early_finish", {completed = routes[citizenId].stopsCompleted, total = routes[citizenId].totalNumberOfStops}), "error")
        end
        if continue then
            depositPay = 0
        end
        local totalToPay = depositPay + routes[citizenId].actualPay
        local payoutDeposit = Lang:t("info.payout_deposit", {value = depositPay})
        if depositPay == 0 then
            payoutDeposit = ""
        end

        player.Functions.AddMoney("bank", totalToPay , 'garbage-payslip')
        TriggerClientEvent('QBCore:Notify', src, Lang:t("success.pay_slip", {total = totalToPay, deposit = payoutDeposit}), "success")
        routes[citizenId] = nil
    else
        TriggerClientEvent('QBCore:Notify', source, Lang:t("error.never_clocked_on"), "error")
    end
end)

QBCore.Commands.Add("cleargarbroutes", "Removes garbo routes for user (admin only)", {{name="id", help="Player ID (may be empty)"}}, false, function(source, args)
    local player = QBCore.Functions.GetPlayer(tonumber(args[1]))
    if not player then return end

    local citizenId = player.PlayerData.citizenid
    local count = 0
    for k in pairs(routes) do
        if k == citizenId then
            count += 1
        end
    end

    TriggerClientEvent('QBCore:Notify', source, Lang:t("success.clear_routes", {value = count}), "success")
    routes[citizenId] = nil
end, "admin")
