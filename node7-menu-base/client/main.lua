local RESOURCE = GetCurrentResourceName()

MenuData = MenuData or {}
MenuData.Opened = {}
MenuData.RegisteredTypes = {}

local MenuType = 'default'
local NuiOpen = false

local Controls = {
    enter = { 0xC7B5340A, 0x43DBF61F },       -- ENTER / INPUT_FRONTEND_ACCEPT fallback
    back = { 0x156F7119, 0x308588E6 },        -- BACKSPACE / INPUT_FRONTEND_CANCEL fallback
    up = { 0x6319DB71, 0x911CB09E },          -- UP
    down = { 0x05CA7C52, 0x4403F97F },        -- DOWN
    left = { 0xA65EBAB4, 0xAD7FCC5B },        -- LEFT
    right = { 0xDEB34313, 0x65F9EC5B }        -- RIGHT
}

local function safeNative(fn, ...)
    if type(fn) ~= 'function' then return false end
    local ok, result = pcall(fn, ...)
    if ok then return result end
    return false
end

local function isControlReleased(list)
    for _, control in ipairs(list) do
        if safeNative(IsControlJustReleased, 0, control) or safeNative(IsDisabledControlJustReleased, 0, control) then
            return true
        end
    end
    return false
end

local function setFocus(enabled)
    NuiOpen = enabled and true or false
    safeNative(SetNuiFocus, NuiOpen, NuiOpen)
    safeNative(SetNuiFocusKeepInput, not NuiOpen)
end

local function normalizeData(data)
    data = data or {}
    data.title = data.title or 'NODE7 MENU'
    data.subtext = data.subtext or ''
    data.align = data.align or 'top-left'
    data.elements = data.elements or data.items or data.options or {}
    return data
end

MenuData.RegisteredTypes.default = {
    open = function(namespace, name, data, setnui)
        data = normalizeData(data)
        SendNUIMessage({
            ak_menubase_action = 'openMenu',
            ak_menubase_namespace = namespace,
            ak_menubase_name = name,
            ak_menubase_data = data
        })
        if setnui then setFocus(true) end
    end,

    close = function(namespace, name)
        SendNUIMessage({
            ak_menubase_action = 'closeMenu',
            ak_menubase_namespace = namespace,
            ak_menubase_name = name
        })
        setFocus(false)
    end
}

local function removeOpened(typeName, namespace, name)
    for i = #MenuData.Opened, 1, -1 do
        local opened = MenuData.Opened[i]
        if opened and opened.type == typeName and opened.namespace == namespace and opened.name == name then
            table.remove(MenuData.Opened, i)
        end
    end
end

function MenuData.Open(typeName, namespace, name, data, submit, cancel, change, close, setnui)
    typeName = typeName or 'default'
    namespace = namespace or RESOURCE
    name = name or 'menu'
    data = normalizeData(data)

    if not MenuData.RegisteredTypes[typeName] then
        typeName = 'default'
    end

    local menu = {
        type = typeName,
        namespace = namespace,
        name = name,
        data = data,
        submit = submit,
        cancel = cancel,
        change = change,
        closeCallback = close,
        setnui = setnui == true
    }

    function menu.close()
        MenuData.RegisteredTypes[typeName].close(namespace, name)
        removeOpened(typeName, namespace, name)
        if type(menu.closeCallback) == 'function' then
            menu.closeCallback(name)
        end
    end

    function menu.update(query, newData)
        query = query or {}
        newData = newData or {}
        for i = 1, #(menu.data.elements or {}) do
            local element = menu.data.elements[i]
            local match = true
            for key, value in pairs(query) do
                if element[key] ~= value then match = false break end
            end
            if match then
                for key, value in pairs(newData) do
                    element[key] = value
                end
            end
        end
    end

    function menu.refresh()
        MenuData.RegisteredTypes[typeName].open(namespace, name, menu.data, menu.setnui)
    end

    function menu.setElement(index, key, value)
        if menu.data.elements and menu.data.elements[index] then
            menu.data.elements[index][key] = value
        end
    end

    function menu.setElements(newElements)
        menu.data.elements = newElements or {}
    end

    function menu.setTitle(value)
        menu.data.title = value or menu.data.title
    end

    function menu.removeElement(query)
        query = query or {}
        for i = #(menu.data.elements or {}), 1, -1 do
            local element = menu.data.elements[i]
            local match = true
            for key, value in pairs(query) do
                if element[key] ~= value then match = false break end
            end
            if match then table.remove(menu.data.elements, i) end
        end
    end

    MenuData.Opened[#MenuData.Opened + 1] = menu
    MenuData.RegisteredTypes[typeName].open(namespace, name, data, menu.setnui)
    safeNative(PlaySoundFrontend, 'SELECT', 'RDRO_Character_Creator_Sounds', true, 0)
    return menu
end

function MenuData.Close(typeName, namespace, name)
    typeName = typeName or 'default'
    for i = #MenuData.Opened, 1, -1 do
        local menu = MenuData.Opened[i]
        if menu and menu.type == typeName and menu.namespace == namespace and menu.name == name then
            menu.close()
        end
    end
end

function MenuData.CloseAll()
    for i = #MenuData.Opened, 1, -1 do
        local menu = MenuData.Opened[i]
        if menu then menu.close() end
    end
    MenuData.Opened = {}
    SendNUIMessage({ ak_menubase_action = 'forceClose' })
    setFocus(false)
end

function MenuData.GetOpened(typeName, namespace, name)
    typeName = typeName or 'default'
    for i = 1, #MenuData.Opened do
        local menu = MenuData.Opened[i]
        if menu and menu.type == typeName and menu.namespace == namespace and menu.name == name then
            return menu
        end
    end
    return nil
end

function MenuData.GetOpenedMenus()
    return MenuData.Opened
end

function MenuData.IsOpen(typeName, namespace, name)
    return MenuData.GetOpened(typeName, namespace, name) ~= nil
end

function MenuData.ReOpen(oldMenu)
    if not oldMenu then return nil end
    return MenuData.Open(oldMenu.type, oldMenu.namespace, oldMenu.name, oldMenu.data, oldMenu.submit, oldMenu.cancel, oldMenu.change, oldMenu.closeCallback, oldMenu.setnui)
end

local function getMenuFromPayload(data)
    if type(data) ~= 'table' then return nil end
    return MenuData.GetOpened(MenuType, data._namespace, data._name)
end

RegisterNUICallback('menu_submit', function(data, cb)
    safeNative(PlaySoundFrontend, 'SELECT', 'RDRO_Character_Creator_Sounds', true, 0)
    local menu = getMenuFromPayload(data)
    if menu and type(menu.submit) == 'function' then
        menu.submit(data, menu)
    end
    cb({})
end)

RegisterNUICallback('menu_cancel', function(data, cb)
    safeNative(PlaySoundFrontend, 'BACK', 'RDRO_Character_Creator_Sounds', true, 0)
    local menu = getMenuFromPayload(data)
    if menu and type(menu.cancel) == 'function' then
        menu.cancel(data, menu)
    elseif menu then
        menu.close()
    else
        MenuData.CloseAll()
    end
    cb({})
end)

RegisterNUICallback('menu_change', function(data, cb)
    local menu = getMenuFromPayload(data)
    if menu and data.elements then
        for i = 1, #data.elements do
            menu.setElement(i, 'value', data.elements[i].value)
            menu.setElement(i, 'selected', data.elements[i].selected == true)
        end
        if type(menu.change) == 'function' then
            menu.change(data, menu)
        end
    end
    cb({})
end)

RegisterNUICallback('playsound', function(_, cb)
    safeNative(PlaySoundFrontend, 'NAV_LEFT', 'PAUSE_MENU_SOUNDSET', true, 0)
    cb({})
end)

RegisterNUICallback('force_close', function(_, cb)
    MenuData.CloseAll()
    cb({})
end)

CreateThread(function()
    while true do
        if #MenuData.Opened > 0 then
            Wait(0)
            if isControlReleased(Controls.enter) then
                SendNUIMessage({ ak_menubase_action = 'controlPressed', ak_menubase_control = 'ENTER' })
            elseif isControlReleased(Controls.back) then
                SendNUIMessage({ ak_menubase_action = 'controlPressed', ak_menubase_control = 'BACKSPACE' })
            elseif isControlReleased(Controls.up) then
                SendNUIMessage({ ak_menubase_action = 'controlPressed', ak_menubase_control = 'TOP' })
            elseif isControlReleased(Controls.down) then
                SendNUIMessage({ ak_menubase_action = 'controlPressed', ak_menubase_control = 'DOWN' })
            elseif isControlReleased(Controls.left) then
                SendNUIMessage({ ak_menubase_action = 'controlPressed', ak_menubase_control = 'LEFT' })
            elseif isControlReleased(Controls.right) then
                SendNUIMessage({ ak_menubase_action = 'controlPressed', ak_menubase_control = 'RIGHT' })
            end
        else
            Wait(250)
        end
    end
end)

AddEventHandler('node7-menu-base:getData', function(cb)
    if type(cb) == 'function' then cb(MenuData) end
end)

RegisterNetEvent('node7-menu-base:client:closeAll', function()
    MenuData.CloseAll()
end)

exports('GetMenuData', function()
    return MenuData
end)

exports('CloseAll', function()
    MenuData.CloseAll()
end)

-- Compatibility bridge for converted legacy resources during migration.
AddEventHandler('redemrp_menu_base:getData', function(cb)
    if type(cb) == 'function' then cb(MenuData) end
end)

CreateThread(function()
    print('[node7-menu-base] client ready')
end)
