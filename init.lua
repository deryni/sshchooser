-- Copyright (c) 2016 Etan Reisner
-- luacheck: read globals hs
-- luacheck: max comment line length 125

--- === SSHChooser ===
---
--- Start new SSH session from a chooser or menu
---
--- Download: [https://github.com/Hammerspoon/Spoons/raw/master/Spoons/SSHChooser.spoon.zip](SSHChooser.spoon.zip)

local obj = {
    name = 'SSHChooser',
    version = '0.5.0',
    author = 'Etan Reisner <deryni@gmail.com>',
    license = 'MPL-2.0',
    homepage = 'https://github.com/deryni/sshchooser',
}

----

-- Variables

--- SSHChooser.logger
--- Variable
--- Logger object used within the Spoon. Can be accessed to set the default log level for the messages coming from the Spoon.
obj.logger = hs.logger.new('SSHChooser', 'info')

--- SSHChooser.useMenu
--- Variable
--- Enable menubar item
obj.useMenu = true

--- SSHChooser.launcher
--- Variable
--- Launcher to use to launch the SSH session
obj.launcher = 'iterm2'

----

-- Internals

local sshDir = ('%s/.ssh'):format(os.getenv('HOME'))

local parseFns = dofile(hs.spoons.resourcePath('parse_fns.lua'))

-- The ssh chooser
local chooser = nil
-- The SSH menu
local menu = nil

local launchCmd

local defaultHotkeys = {
    showChooser = {{'shift', 'cmd',}, 'p'}
}

local function loadLauncher()
    launchCmd = dofile(hs.spoons.resourcePath(('launcher/%s.lua'):format(obj.launcher)))
end

--  Launch helper functions
local launchHelpers = {
    shell_quote = function (val)
        if ('number' == type(val)) or tonumber(val) then
            return val
        end

        if 'string' ~= type(val) then
            return
        end

        return "'"..val:gsub("'", [['\'']]).."'"
    end,

    escape_quotes = function (val)
        return val:gsub('"', [[\"]])
    end,

    do_applescript = function (ascmd)
        local ok, _, rawout = hs.osascript.applescript(ascmd) -- luacheck: no unused
        --[[
        local lvl = ok and 'i' or 'e'
        if type(rawout) == 'table' then
            for k, v in pairs(rawout) do
                obj.logger[lvl](('%s = %s'):format(tostring(k), tostring(v)))
            end
        else
            if rawout ~= 'null()' then
                obj.logger[lvl](('%s: %s'):format(type(rawout), tostring(rawout)))
            end
        end
        --]]
    end,
}

----

local function doSsh(tab)
    if not tab then
        return
    end

    local host = tab.text or tab.host or tab.title
    if not host then
        return
    end

    if type(host) ~= 'string' then
        host = host:getString()
    end

    if not launchCmd then
        loadLauncher()
    end

    return launchCmd(launchHelpers, host)
end

local function newChooser()
    local _chooser = hs.chooser.new(doSsh)

    _chooser:rows(5)
    _chooser:width(40)
    _chooser:searchSubText(true)
    _chooser:placeholderText('SSH host')

    -- Clear the query and reset the scroll on dismissal.
    _chooser:hideCallback(function()
        _chooser:query('')
        _chooser:selectedRow(0)
    end)

    return _chooser
end

local function doSshMenu(mods, tab) -- luacheck: no unused args
    if (not tab) or (not tab.title) then
        return
    end

    return doSsh(tab)
end

local function newMenu()
    if not obj.useMenu then
        return
    end

    local _menu = hs.menubar.new()

    _menu:setTitle('SSH')

    return _menu
end

local function checkConfigChanged(paths)
    for _, v in ipairs(paths) do
        if v:match('/config$') or v:match('/known_hosts$') then
            obj:loadHosts()
            break
        end
    end
end

local function makeMenu(hosts)
    local hostMenu = {}

    for _, host in ipairs(hosts) do
        local m = {
            title = host.text,
            fn = doSshMenu,
            tooltip = host.subText,
        }
        if host.subText and (not host.subText:match('%s')) then
            m.host = m.title
            m.title = m.title..(' (%s)'):format(m.tooltip)
        end

        hostMenu[#hostMenu + 1] = m
    end

    return hostMenu
end

local function showChooser()
    if not chooser then
        chooser = newChooser()

        obj:loadHosts()
    end

    chooser:show()
end

----

-- Callable functions

--- SSHChooser.loadHosts()
--- Method
--- Load the SSH configuration and Known Hosts and populate the chooser and
--- menu. Normally called automatically by pathwatcher should only need to be
--- called manually if start() is not used.
---
--- Parameters:
---  * None
function obj:loadHosts()
    local hosts = parseFns.parse_config(sshDir)

    chooser:choices(hosts)

    if self.useMenu then
        menu:setMenu(makeMenu(hosts))
    end
end

----

--- SSHChooser:init()
--- Method
--- Register a pathwatcher for SSH configuration changes.
---
--- Parameters:
---  * None
---
--- Returns:
---  * The SSHChooser
function obj:init()
    self._pathWatcher = hs.pathwatcher.new(sshDir, checkConfigChanged)

    return self
end

--- SSHChooser:start()
--- Method
--- Activate the pathwatcher for SSH configuration changes.
--- Creates the chooser and menu (if enabled).
---
--- Parameters:
---  * None
---
--- Returns:
---  * The SSHChooser
function obj:start()
    self._pathWatcher:start()

    loadLauncher()

    chooser = newChooser()

    menu = newMenu()

    self:loadHosts()

    return self
end

--- SSHChooser:stop()
--- Method
--- Stops the pathwatcher for SSH configuration changes.
--- Deletes the chooser and menu.
---
--- Parameters:
---  * None
---
--- Returns:
---  * The SSHChooser
function obj:stop()
    self._pathWatcher:stop()

    if chooser then
        chooser:delete()
    end

    if menu then
        menu:delete()
    end

    return self
end

--- SSHChooser:bindHotkeys(mapping)
--- Method
--- Binds hotkeys for SSHChooser
---
--- Parameters:
---  * mapping - A table containing hotkey objifier/key details for the following items:
---   * showChooser - Show the SSH session chooser
function obj:bindHotkeys(mapping)
    local spec = {
        showChooser = showChooser
    }

    hs.spoons.bindHotkeysToSpec(spec, mapping or defaultHotkeys)

    return self
end

return obj
