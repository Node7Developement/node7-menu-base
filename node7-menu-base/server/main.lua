local RESOURCE = GetCurrentResourceName()
local VERSION = '1.0.0'

local function hasAdmin(source)
    if source == 0 then return true end
    return IsPlayerAceAllowed(source, 'node7.menu_base.admin')
        or IsPlayerAceAllowed(source, 'node7.admin')
        or IsPlayerAceAllowed(source, 'node7.owner')
end

RegisterCommand('node7menubase', function(source)
    if not hasAdmin(source) then
        if source > 0 then
            TriggerClientEvent('chat:addMessage', source, { args = { 'node7-menu-base', 'Access denied.' } })
        end
        return
    end

    local message = ('%s running v%s'):format(RESOURCE, VERSION)
    if source == 0 then
        print(('[node7-menu-base] %s'):format(message))
    else
        TriggerClientEvent('chat:addMessage', source, { args = { 'node7-menu-base', message } })
    end
end, false)

CreateThread(function()
    print(('[node7-menu-base] started v%s'):format(VERSION))
end)
