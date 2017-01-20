# sshchooser
An SSH host chooser menu for Hammerspoon

# Installation
- Run `git clone https://github.com/deryni/sshchooser.git`
- Run `make install` (or `make all` for other installation options)
- Open Hammerspoon config and add `dofile("sshchooser.lua")`
- Reload Hammerspoon (if you don't have automatic config reloading enabled)

# Configuration

The default keybinding for the chooser is `Ctrl-Alt-p`.

The binding can be configured via the `$HOME/.hammerspoon/sshchooser.cfg`
file:

    -- Bind to Command-Shift-S.
    sshmods = {"command", "shift"}
    sshkey = "s"
