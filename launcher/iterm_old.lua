-- Copyright (c) 2016 Etan Reisner

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

return function(lh, host)
    return lh.do_applescript(ascmd:format(lh.shell_quote(host)))
end
