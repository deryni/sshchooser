-- Default Configuration
local sshkey = "p"
local sshmods = {"alt", "ctrl"}
local sshfn = "iterm"

-- Code below here

local HOME = HOME or os.getenv("HOME")
if not HOME then
    return
end

local logger = hs.logger.new('sshchooser', 'info')

local function shell_quote(val)
    if ("number" == type(val)) or tonumber(val) then
        return val
    end

    if "string" ~= type(val) then
        return
    end

    return "'"..val:gsub("'", [['\'']]).."'"
end

-- Load user configuration.
local cfgfile = io.open(HOME.."/.hammerspoon/sshchooser.cfg")
if cfgfile then
    local env = {
        HOME = HOME,
        logger = logger,
        sshkey = sshkey,
        sshmods = sshmods,
        sshfn = sshfn,
        shell_quote = shell_quote,
    }

    local cfgstr = cfgfile:read("*a")
    cfgfile:close()

    local chunk, err = load(cfgstr, "sshchooser.cfg", "t", env)
    if chunk then
        chunk()

        if env.sshkey then
            sshkey = env.sshkey
        end
        if env.sshmods then
            sshmods = env.sshmods
        end
        if env.sshfn then
            sshfn = env.sshfn
        end
    end
end

local sshfns = {
    iterm = function(host)
        local ascmd = [[
        tell application "iTerm"
                set myterm to (make new terminal)
                tell myterm
                    launch session "Default"
                    tell the last session
                        write text "exec ssh %s"
                    end tell
                end tell
        end tell]]
        ascmd = ascmd:format(shell_quote(host))

        local ok, res = hs.applescript.applescript(ascmd)
        if not ok then
            if "table" == type(res) then
                for k, v in pairs(res) do
                    logger.ef("%s = %s", tostring(k), tostring(v))
                end
            else
                logger.e(res)
            end
        end
    end,
}

if "string" == type(sshfn) then
    if not sshfns[sshfn] then
        logger.ef("Invalid SSH launcher: %s", sshfn)
        return
    end

    sshfn = sshfns[sshfn]
end

if not sshfn then
    logger.ef("No SSH launcher found.")
    return
end

local function do_ssh(tab)
    if (not tab) or (not tab.text) then
        return
    end

    return sshfns[sshfn](tab.text)
end

local function ssh_get_hosts()
    local ssh_hosts = {}
    -- Store seen hosts to avoid duplicates.
    -- Can't use the ssh_hosts table as hammerspoon doesn't like that.
    local ssh_hosts_hack = {}

    local function add_config_entry(curhosts, hostname)
        if not curhosts then
            return
        end

        -- Add static hostname to our duplicate table.
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
                local s, e = l:find("^Host ")
                if s then
                    add_config_entry(curhosts, canonical)

                    curhosts, canonical = {}, nil
                    for h in l:sub(e):gmatch("%S+") do
                        curhosts[#curhosts + 1] = h
                    end
                else
                    local tmp
                    s, e, tmp = l:find("^Hostname (%S+)")
                    if s then
                        canonical = tmp
                    end
                end
            end
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
            local st, en, hostname = string.find(l, "^([^%s,]+)")
            if hostname and (not ssh_hosts_hack[hostname]) then
                ssh_hosts[#ssh_hosts + 1] = {
                    text = hostname,
                    subText = "",
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

local function get_ssh_chooser()
    if not sshchooser then
        sshchooser = hs.chooser.new(do_ssh)

        sshchooser:choices(ssh_get_hosts)
        sshchooser:rows(5)
        sshchooser:width(40)
        sshchooser:searchSubText(true)
    end

    return sshchooser
end

local hotkey

local function sethotkey()
    if hotkey then
        hotkey:delete()
    end

    hotkey = hs.hotkey.bind(sshmods, sshkey, function()
        sshchooser = get_ssh_chooser()
        return sshchooser:show()
    end)
end

sethotkey()

local function ssh_reload(files)
    for _, file in ipairs(files) do
        if file:match("/config$") or
            file:match("/known_hosts$")
        then
            sshchooser:refreshChoicesCallback()
        elseif file:match("/sshchooser.cfg") then
            sethotkey()
        end
    end
end

hs.pathwatcher.new(HOME.."/.ssh", ssh_reload):start()
