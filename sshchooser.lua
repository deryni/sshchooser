-- Default Configuration
local sshmods = {"alt", "ctrl"}
local sshkey = "p"

local HOME = HOME or os.getenv("HOME")

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

hs.hotkey.bind(sshmods, sshkey, function()
    sshchooser = get_ssh_chooser()
    return sshchooser:show()
end)
