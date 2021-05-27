-- Copyright (c) 2016 Etan Reisner

local ascmd = [[
    tell application "Terminal"
        activate
        tell application "System Events" to keystroke "n" using {command down}
        do script "unset -v HISTFILE; tput clear; exec ssh %s" in front window
    end tell
]]

return function(lh, host)
    return lh.do_applescript(ascmd:format(lh.shell_quote(host)))
end
