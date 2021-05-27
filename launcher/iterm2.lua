-- Copyright (c) 2016 Etan Reisner

local ascmd = [[
    tell application "iTerm"
        set newWindow to (create window with profile "Default" command "ssh %s")
        tell newWindow
            select
        end tell
    end tell
]]

return function(lh, host)
    return lh.do_applescript(ascmd:format(lh.escape_quotes(host)))
end
