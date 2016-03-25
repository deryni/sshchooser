local HOME = HOME or os.getenv("HOME")
if not HOME then
    return
end

-- Default Configuration
local sshmods = {"alt", "ctrl"}
local sshkey = "p"

local logger = hs.logger.new('sshchooser', 'info')

-- Load user configuration.
local cfgfile = io.open(HOME.."/.hammerspoon/sshchooser.cfg")
if cfgfile then
    local env = {}
    local chunk, err = load(cfgfile:read("*a"), "sshchooser.cfg", "t", env)
    cfgfile:close()
    if chunk then
        chunk()

        if env.sshkey then
            sshkey = env.sshkey
        end
        if env.sshmods then
            sshmods = env.sshmods
        end
    end
end

local function ssh_get_hosts()
    local ssh_hosts = {}

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
            if hostname then
                ssh_hosts[#ssh_hosts + 1] = {
                    text = hostname,
                    subText = "",
                }
            end
        end
        f:close()
    end

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

local function sethotkey
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
        if file:match("/sshchooser.cfg") then
            sethotkey()
            break
        end
    end
end

hs.pathwatcher.new(HOME.."/.ssh", ssh_reload):start()
