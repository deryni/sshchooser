-- Copyright (c) 2016 Etan Reisner

local ascmd = [[
    tell application "iTerm"
        set newTab to (create tab with default profile in current window command "ssh %s")
        tell newTab
            select
        end tell
        activate
    end tell
]]

return function(lh, host)
    return lh.do_applescript(ascmd:format(lh.escape_quotes(host)))
end
