-----------------------------
---- NAVIGATION PRESETS ----
-----------------------------

-- Starting keys for moving around, chosen in Settings › Hyprland ›
-- Keybinds (Navigation keys) or the welcome screen. local/settings.lua
-- (generated) calls lyne_bind_preset(name) from conf/binds.lua, which makes
-- these the default keys of the binds below; the user's own changes are
-- applied after it, so they stay.
--   vim     the keys of conf/keybinds.lua: H/J/K/L
--   arrows  the arrow keys instead of H/J/K/L
--   both    H/J/K/L plus the arrow keys on the "(arrow)" binds
--   komorebi  the layout of komorebi + whkd on Windows: arrows, Super +
--             Shift + E/I/N/O to resize (50 px), Super + Ctrl + - / = for
--             workspaces, Super + , / . for monitors, Alt + Space launcher
-- Keys starting with "_" are options, not bind ids: _resize_step sets the
-- pixels per resize press (LYNE_RESIZE_STEP in conf/keybinds.lua)

local directions = { left = "left", right = "right", up = "up", down = "down" }

-- Modifiers of each directional group, as in conf/keybinds.lua
local groups = {
    focus = "SUPER",
    move = "SUPER + SHIFT",
    resize = "SUPER + ALT",
}

-- Workspace steps: next is right, previous is left
local steps = {
    ["workspace-next"] = "SUPER + CTRL + right",
    ["workspace-prev"] = "SUPER + CTRL + left",
    ["move-to-next"] = "SUPER + CTRL + SHIFT + right",
    ["move-to-prev"] = "SUPER + CTRL + SHIFT + left",
}

local function arrow_keys(suffix)
    local keys = {}
    for group, mods in pairs(groups) do
        for dir, key in pairs(directions) do
            keys[group .. "-" .. dir .. suffix] = mods .. " + " .. key
        end
    end
    for id, combo in pairs(steps) do
        keys[id .. suffix] = combo
    end
    return keys
end

-- "" frees keys used elsewhere in this layout (Super + Tab, Super + , / .)
local komorebi = {
    _resize_step = 50,

    ["focus-left"] = "SUPER + left",
    ["focus-right"] = "SUPER + right",
    ["focus-up"] = "SUPER + up",
    ["focus-down"] = "SUPER + down",
    ["move-left"] = "SUPER + SHIFT + left",
    ["move-right"] = "SUPER + SHIFT + right",
    ["move-up"] = "SUPER + SHIFT + up",
    ["move-down"] = "SUPER + SHIFT + down",

    ["resize-down"] = "SUPER + SHIFT + E",
    ["resize-up"] = "SUPER + SHIFT + I",
    ["resize-right"] = "SUPER + SHIFT + N",
    ["resize-left"] = "SUPER + SHIFT + O",

    ["workspace-prev"] = "SUPER + CTRL + minus",
    ["workspace-next"] = "SUPER + CTRL + equal",
    ["move-to-prev"] = "SUPER + CTRL + SHIFT + minus",
    ["move-to-next"] = "SUPER + CTRL + SHIFT + equal",

    ["focus-monitor-prev"] = "SUPER + comma",
    ["focus-monitor-next"] = "SUPER + period",
    ["move-to-monitor-prev"] = "SUPER + SHIFT + comma",
    ["move-to-monitor-next"] = "SUPER + SHIFT + period",

    ["toggle-float"] = "SUPER + F",
    ["maximize"] = "SUPER + SHIFT + F",
    ["fullscreen"] = "SUPER + CTRL + F",
    ["toggle-split"] = "",
    ["layout-action-back"] = "",
    ["swap-column-left"] = "",
    ["swap-column-right"] = "",

    ["file-manager"] = "SUPER + E",
    ["lock-screen"] = "SUPER + L",
    ["power-menu"] = "SUPER + SHIFT + Escape",
    ["power-menu-alt"] = "ALT + F4",
    ["launcher"] = "ALT + space",
    ["launcher-alt"] = "SUPER + SUPER_L",
    ["zoom-in"] = "SUPER + ALT + KP_Add",
    ["zoom-out"] = "SUPER + ALT + KP_Subtract",
}

return {
    vim = {},
    arrows = arrow_keys(""),
    both = arrow_keys("-alt"),
    komorebi = komorebi,
}
