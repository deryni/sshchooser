-- Basic sanity check
local HOME = HOME or os.getenv("HOME")
if not HOME then
    return
end

-- Default Configuration
local def_sshkey, sshkey = "p"
local def_sshmods, sshmods = {"alt", "ctrl"}
local def_sshfn, sshfn = "iterm"

-- {{{ Helper functions
local function shell_quote(val)
    if ("number" == type(val)) or tonumber(val) then
        return val
    end

    if "string" ~= type(val) then
        return
    end

    return "'"..val:gsub("'", [['\'']]).."'"
end

local function escape_quotes(val)
    return val:gsub('"', [[\"]])
end
-- }}} Helper functions

-- Code below here

local logger = hs.logger.new('sshchooser', 'info')

-- {{{ Terminal launchers
local function do_applescript(ascmd)
    local ok, out, rawout = hs.osascript.applescript(ascmd)
    local lvl = ok and "i" or "e"
    if type(rawout) == "table" then
        for k, v in pairs(rawout) do
            logger[lvl](("%s = %s"):format(tostring(k), tostring(v)))
        end
    else
        if rawout ~= "null()" then
            logger[lvl](("%s: %s"):format(type(rawout), tostring(rawout)))
        end
    end
end

local sshfns = {
    iterm = function(host)
        local ascmd = [[
        tell application "iTerm"
            set newWindow to (create window with profile "Default" command "ssh %s")
            tell newWindow
                select
            end tell
        end tell]]

        return do_applescript(ascmd:format(escape_quotes(host)))
    end,

    iterm_old = function(host)
        local ascmd = [[
        tell application "iTerm"
                set myterm to (make new terminal)
                tell myterm
                    launch session "Default"
                    tell the last session
                        write text "unset HISTFILE; tput clear; printf '\\x1b]50;ClearScrollback\\x07'; exec ssh %s"
                    end tell
                end tell
        end tell]]
        ascmd = ascmd:format(shell_quote(host))

        return do_applescript(ascmd)
    end,
}
-- }}} Terminal launchers

-- Load user configuration.
local function load_config()
    -- Start with the defaults.
    local env = setmetatable({
        sshkey = def_sshkey,
        sshmods = def_sshmods,
        sshfn = def_sshfn,
    }, {__index = {
        HOME = HOME,
        logger = logger,
        shell_quote = shell_quote,
        escape_quotes = escape_quotes,
    }})

    local cfgfile = io.open(HOME.."/.hammerspoon/sshchooser.cfg")
    if cfgfile then
        local cfgstr = cfgfile:read("*a")
        cfgfile:close()

        local chunk, err = load(cfgstr, "sshchooser.cfg", "t", env)
        if chunk then
            local ok, ret = pcall(chunk)
            if not ok then
                err = ret
            end
        end

        if err then
            logger.wf("Failed to load sshchooser.cfg: %s", err)
        end
    end

    sshkey = env.sshkey
    sshmods = env.sshmods
    if (("string" == type(env.sshfn)) and sshfns[env.sshfn]) or
       ("function" == type(env.sshfn))
    then
        sshfn = env.sshfn
    else
        logger.wf("Invalid SSH launcher: %s", env.sshfn)
    end
end
load_config()

if not sshfn then
    logger.ef("No SSH launcher found.")
    return
end

-- subText value for IP entries. Set below after version detection.
local subTexthack

local function ssh_get_hosts()
    local ssh_hosts = {}
    -- Store seen hosts to avoid duplicates.
    -- Can't use the ssh_hosts table as hammerspoon doesn't like that.
    local ssh_hosts_hack = {}

    local function add_config_entry(curhosts, hostname)
        if not curhosts then
            return
        end

        -- Add canonical hostname to our duplicate table.
        if hostname and (not hostname:find("%%")) then
            ssh_hosts_hack[hostname] = true
        end

        for _, h in ipairs(curhosts) do
            if not ssh_hosts_hack[h] then
                local curname = hostname and hostname:gsub("%%h", h)

                ssh_hosts[#ssh_hosts + 1] = {
                    text = h,
                    subText = curname,
                }

                -- Add current host to our duplicate table.
                ssh_hosts_hack[h] = true
                -- Add expanded hostname to our duplicate table.
                if curname and (not ssh_hosts_hack[curname]) then
                    ssh_hosts_hack[curname] = true
                end
            end
        end
    end

    local function get_config_hosts()
        local f = io.open(HOME.."/.ssh/config")
        if f then
            local curhosts, canonical
            for l in f:lines() do
                -- Trim leading and trailing spaces.
                l = l:gsub("^%s*", ""):gsub("%s*$", "")

                local s, e = l:find("^Host%s+")
                if s then
                    -- About to start a new Host entry so add entries for all
                    -- previously seen hosts.
                    add_config_entry(curhosts, canonical)

                    -- Reset current host information.
                    curhosts, canonical = {}, nil
                    local hoststr = l:sub(e+1)
                    for h in hoststr:gmatch("%S+") do
                        if not h:find("*", 1, true) then
                            curhosts[#curhosts + 1] = h
                        end
                    end
                else
                    local tmp = l:match("^Hostname (%S+)")
                    if tmp then
                        canonical = tmp
                    end
                end
            end
            -- Add entries for the last Host in the file.
            add_config_entry(curhosts, canonical)
            f:close()
        end
    end

    local function get_known_hosts()
        local f, err = io.open(HOME.."/.ssh/known_hosts")
        if not f then
            logger.i("Failed to open known_hosts file.")
            if err then
                logger.i(err)
            end

            return
        end

        for l in f:lines() do
            local hostname = l:match("^([^%s,]+)")
            if hostname and (not ssh_hosts_hack[hostname]) then
                ssh_hosts[#ssh_hosts + 1] = {
                    text = hostname,
                    subText = subTexthack,
                }
                -- Add host to our duplicate table.
                ssh_hosts_hack[hostname] = true
            end
        end
        f:close()
    end

    get_config_hosts()
    get_known_hosts()

    return ssh_hosts
end

local sshchooser

local function do_ssh(tab)
    if (not tab) or (not tab.text) then
        return
    end

    sshchooser:query("")

    return sshfns[sshfn](tab.text)
end

local function get_ssh_chooser()
    local hsversion, newversion = hs.processInfo.version, "0.9.51"

    local ok, semver = pcall(require, "semver")
    if ok and semver then
        newversion = semver(newversion)
        hsversion = semver(hsversion)
    end

    -- Hammerspoon 0.9.51 and newer handle nil as subText well.
    -- Earlier versions do not (so we use a blank string).
    subtexthack = (hsversion < newversion) and "" or nil

    if not sshchooser then
        sshchooser = hs.chooser.new(do_ssh)

        sshchooser:choices(ssh_get_hosts)
        sshchooser:rows(5)
        sshchooser:width(40)
        sshchooser:searchSubText(true)
    end

    return sshchooser
end

-- Store hot key binding.
local hotkey

local function set_hot_key()
    if hotkey then
        hotkey:delete()
    end

    hotkey = hs.hotkey.bind(sshmods, sshkey, function()
        sshchooser = get_ssh_chooser()
        return sshchooser:show()
    end)
end

set_hot_key()

local function ssh_reload(files)
    for _, file in ipairs(files) do
        if file:match("/config$") or
            file:match("/known_hosts$")
        then
            sshchooser:refreshChoicesCallback()
            break
        elseif file:match("/sshchooser.cfg$") then
            load_config()
            set_hot_key()
        end
    end
end

sshwatchers = {
    hs.pathwatcher.new(HOME.."/.ssh", ssh_reload):start(),
    hs.pathwatcher.new(HOME.."/.hammerspoon", ssh_reload):start(),
}
