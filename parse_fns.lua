-- Copyright (c) 2016 Etan Reisner
-- luacheck: read globals hs

local parse_fns = {}

local function do_entry(hosts, seen, newhosts)
    local cEntry

    for _, newhost in ipairs(newhosts) do
        if seen[newhost] then
            cEntry = seen[newhost]
            break
        end
    end

    if not cEntry then
        cEntry = {
            text = newhosts[1],
        }
        hosts[#hosts + 1] = cEntry
        seen[newhosts[1]] = cEntry
    end

    for _, newhost in ipairs(newhosts) do
        if not seen[newhost] then
            if not cEntry.hosts then
                cEntry.hosts = {}
            end
            cEntry.hosts[#cEntry.hosts + 1] = newhost
        end
        seen[newhost] = cEntry
    end

    if newhosts.username then
        cEntry.username = newhosts.username
    end

    return cEntry
end

local function add_config_entry(hosts, seen, hostpats)
    if (not hostpats) or (#hostpats == 0) then
        return
    end

    -- Entries with %h in them need every Host to be its own chooser entry.
    if hostpats.realhost and hostpats.realhost:find('%h', 1, true) then
        for _, hostpat in ipairs(hostpats) do
            local fullname = hostpats.realhost:gsub("%%h", hostpat)
            do_entry(hosts, seen, {fullname, username = hostpats.username})
        end

       return
    end

    -- Otherwise just add the real hostname to the hostpats list.
    hostpats[#hostpats + 1] = hostpats.realhost
    hostpats.realhost = nil

    do_entry(hosts, seen, hostpats)
end

function parse_fns.get_config_hosts(hosts, seen, configFile)
    local f = io.open(configFile)
    if not f then
        return hosts
    end

    local hostpats = {}
    for line in f:lines() do
        -- Trim leading and trailing spaces.
        line = line:gsub("^%s*", ""):gsub("%s*$", "")

        local s, e = line:find("^Host%s+")
        if s then
            -- Found a new Host entry so add all previously seen hosts.
            add_config_entry(hosts, seen, hostpats)

            -- Reset current host information.
            hostpats = {}

            -- Extract host match patterns
            local hoststr = line:sub(e+1)
            for hostpat in hoststr:gmatch("%S+") do
                -- Skip wildcard patterns, we can't use them
                if not hostpat:find("[*?]", 1) then
                    hostpats[#hostpats + 1] = hostpat
                end
            end
        else
            -- Found real hostname for current host patterns
            local tmp = line:match("^Hostname +(%S+)")
            if tmp then
                hostpats.realhost = tmp
            end
            -- Save User to format a leading `user@` on the labels.
            tmp = line:match("^User +(%S+)")
            if tmp then
                hostpats.username = tmp
            end
        end
    end
    f:close()

    -- Add entries for the last Host in the file.
    add_config_entry(hosts, seen, hostpats)

    return hosts
end

local function hashed_hostname(hostname)
    return hostname:sub(1,1) == "|"
end

function parse_fns.get_known_hosts(hosts, seen, knownhostsfile)
    local f = io.open(knownhostsfile)
    if not f then
        return hosts
    end

    local klines = {}

    for line in f:lines() do
        local khosts = {}

        local _, e, hoststr = line:gsub('^%s*', ''):find('^([^%s]+)')
        if not hoststr then
            -- Ignore blank lines
            hoststr = ''
        elseif hoststr == "@revoked" then
            -- Ignore @revoked marker lines
            hoststr = ''
        elseif hoststr == '@cert-authority' then
            -- Skip the @cert-authority marker field
            hoststr = line:sub(e+2):match('^([^%s]+)')
        elseif hoststr:match('^#') then
            -- Ignore comment lines
            hoststr = ''
        end

        -- Collect host entries for this line
        for hostpat in hoststr:gmatch("[^,]+") do
            -- Only handle non-negated host patterns
            if not hostpat:match("^!") and (not hashed_hostname(hostpat)) then
                -- Skip wildcard patterns, we can't use them
                if not hostpat:find("[*?]", 1) then
                    hostpat = hostpat:gsub('^%[', '')
                    hostpat = hostpat:gsub('%]:%d+$', '')
                    if not hashed_hostname(hostpat) then
                        khosts[#khosts + 1] = hostpat
                    end
                end
            end
        end

        if #khosts > 0 then
            klines[#klines + 1] = khosts
        end
    end
    f:close()

    for _,kline in ipairs(klines) do
        do_entry(hosts, seen, kline)
    end

    return hosts
end

function parse_fns.parse_config(sshDir)
    local hosts, seen = {}, {}

    parse_fns.get_config_hosts(hosts, seen, sshDir .. '/config')
    parse_fns.get_known_hosts(hosts, seen, sshDir .. '/known_hosts')

    for _, v in ipairs(hosts) do
        if v.hosts then
            v.subText = table.concat(v.hosts, ' ')
            v.hosts = nil
        end
        if v.username then
            local s = hs.styledtext.new(v.username..'@', {color = hs.drawing.color.x11.gray})
            v.text = s .. hs.styledtext.new(v.text)
            v.username = nil
        end
    end

    return hosts
end

return parse_fns
