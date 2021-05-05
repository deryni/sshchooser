-- Copyright (c) 2016 Etan Reisner

local parse_fns = {}

local function add_config_entry(hosts, seen, hostpats)
    if (not hostpats) or (#hostpats == 0) then
        return
    end

    -- Entries with %h in them need every Host to be its own chooser entry.
    if hostpats.canonical and hostpats.canonical:find('%h', 1, true) then
        for _, hostpat in ipairs(hostpats) do
            local fullname = hostpats.canonical:gsub("%%h", hostpat)
            add_config_entry(hosts, seen, {fullname, username = hostpats.username})
        end

        return
    end

    -- Use the canonical hostname or the first host pattern as the "primary" hostname
    local primaryHost = hostpats.canonical or hostpats[1]

    -- Find host entry if we previously created one
    local cEntry = seen[primaryHost]

    if not cEntry then
        cEntry = {
            text = primaryHost
        }
        seen[primaryHost] = cEntry
        hosts[#hosts + 1] = cEntry
    end

    for _, hostpat in ipairs(hostpats) do
        if primaryHost ~= hostpat then
            if not cEntry.hosts then
                cEntry.hosts = {}
            end

            cEntry.hosts[#cEntry.hosts + 1] = hostpat

            -- Add the hostpat to our seen list so we don't duplicate those either.
            seen[hostpat] = cEntry
        end
    end

    -- Handle the unlikely case where we found a duplicate host with a
    -- canonical hostname _after_ finding a previous entry for this host by
    -- mutating the cEntry so that the canonical host is the primary host.
    if hostpats.canonical and (cEntry.text ~= hostpats.canonical) then
        for i,v in ipairs(cEntry.hosts) do
            if v == hostpats.canonical then
                -- Swap the previous primary host into the hosts table.
                cEntry.hosts[i] = cEntry.text
                break
            end
        end

        -- Add the previous primary host into the hosts table.
        cEntry.hosts[cEntry.text] = cEntry.text

        -- Remove the new primary host from the hosts table.
        cEntry.hosts[hostpats.canonical] = nil
        -- Set the new primary host to the canonical one.
        cEntry.text = hostpats.canonical
    end

    if hostpats.username then
        cEntry.text = hs.styledtext.new(hostpats.username..'@', {color = hs.drawing.color.x11.gray}) .. hs.styledtext.new(cEntry.text)
        hostpats.username = nil
    end
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
            -- Found canonical hostname for current host patterns
            local tmp = line:match("^Hostname +(%S+)")
            if tmp then
                hostpats.canonical = tmp
            end
            -- Use User to format a leading `user@` on the chooser (and menu?) labels.
            tmp = line:match("^User +(%S+)")
            if tmp then
                hostpats.username = tmp
            end
        end
    end
    f:close()

    -- Add entries for the last Host in the file.
    add_config_entry(hosts, seen, hostpats)

    --[[
    for i,v in ipairs(hosts) do
        if v.hosts then
            v.subText = table.concat(v.hosts, ' ')
            --v.hosts = nil
        end
    end
    --]]
    return hosts
end

local function hashed_hostname(hostname)
    return hostname:sub(1,1) == "|"
end

function parse_fns.get_known_hosts(hosts, seen, knownhostsfile)
    local f, err = io.open(knownhostsfile)
    if not f then
        --[[
        logger.i("Failed to open known_hosts file.")
        if err then
            logger.i(err)
        end
        --]]

        return hosts
    end

    for line in f:lines() do
        local s, e, hoststr = line:gsub('^%s*', ''):find('^([^%s]+)')
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

        local cEntry
        local khosts = {}

        -- Collect host entries for this line
        for hostpat in hoststr:gmatch("[^,]+") do
            -- Only handle non-negated host patterns
            if not hostpat:match("^!") and (not hashed_hostname(hostpat)) then
                -- Skip wildcard patterns, we can't use them
                if not hostpat:find("[*?]", 1) then
                    hostpat = hostpat:gsub('^%[', '')
                    hostpat = hostpat:gsub('%]:%d+$', '')
                    if not hashed_hostname(hostpat) then
                        if not seen[hostpat] then
                            khosts[#khosts + 1] = hostpat
                            khosts[hostpat] = hostpat
                        else
                            -- Grab the matching cEntry
                            cEntry = seen[hostpat]
                        end
                    end
                end
            end
        end

        if (not cEntry) and (#khosts >= 1) then
            local khost = khosts[1]

            -- We don't have a cEntry for this set of hosts yet.
            -- "Promote" the first host to be the "primary" host.
            cEntry = {
                text = khost,
            }
            -- Remove the new "primary" host from the hosts list.
            table.remove(khosts, 1)
            khosts[khost] = nil
            if #khosts > 0 then
                cEntry.hosts = khosts
            end

            seen[khost] = cEntry

            -- Add the new cEntry to our list.
            hosts[#hosts + 1] = cEntry
        end

        -- We've got a cEntry one way or the other now. Make sure it has all
        -- the new hosts and the seen table is updated.
        for i,khost in ipairs(khosts) do
            if not cEntry.hosts then
                cEntry.hosts = {}
            end
            if not cEntry.hosts[khost] then
                cEntry.hosts[#cEntry.hosts + 1] = khost
            end
            -- Add the khost to our seen list so we don't duplicate it later.
            seen[khost] = cEntry
        end
    end
    f:close()

    return hosts
end

function parse_fns.parse_config(sshDir)
    local hosts, seen = {}, {}

    parse_fns.get_config_hosts(hosts, seen, sshDir .. '/config')
    parse_fns.get_known_hosts(hosts, seen, sshDir .. '/known_hosts')

    for i,v in ipairs(hosts) do
        if v.hosts then
            v.subText = table.concat(v.hosts, ' ')
            v.hosts = nil
        end
    end

    return hosts
end

return parse_fns
