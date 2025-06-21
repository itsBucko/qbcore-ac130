local QBCore = exports['qb-core']:GetCoreObject()

-- Server-side command to toggle AC130 mode, checks if player has ac130_controller item
QBCore.Commands.Add("ac130", "Toggle AC130 mode (requires controller item)", {}, false, function(source, args)
    local Player = QBCore.Functions.GetPlayer(source)
    if Player then
        local hasItem = Player.Functions.GetItemByName("ac130_controller")
        if hasItem then
            -- Tell client to toggle AC130 mode
            TriggerClientEvent("yourscript:toggleAC130", source)
        else
            TriggerClientEvent('QBCore:Notify', source, "You don't have the AC130 controller item!", "error")
        end
    end
end)


RegisterNetEvent('QBCore:RemoveItem')
AddEventHandler('QBCore:RemoveItem', function(itemName, amount)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if Player then
        local removed = Player.Functions.RemoveItem(itemName, amount)
        if removed then
            TriggerClientEvent('QBCore:Notify', src, "Removed " .. amount .. "x " .. itemName)
        else
            TriggerClientEvent('QBCore:Notify', src, "Failed to remove " .. itemName)
        end
    end
end)
