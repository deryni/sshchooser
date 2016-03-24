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

hs.hotkey.bind({"alt", "ctrl"}, "p", function()
    sshchooser = get_ssh_chooser()
    return sshchooser:show()
end)
