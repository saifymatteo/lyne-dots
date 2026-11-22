-- Every navigation preset of hypr/conf/bind_presets.lua applied over the
-- binds of conf/keybinds.lua and conf/specials.lua (with a stand-in `hl`):
-- each preset id must exist, and no two binds may end up on the same keys.
-- Run: lua tests/lua/bind_presets.lua   (or luajit)

local root = (arg and arg[0] or ""):match("^(.*)/tests/lua/") or "."
local hypr = root .. "/hyprland/.config/hypr"
package.path = hypr .. "/?.lua;" .. package.path

-- Stand-in for Hyprland's Lua API: binds are recorded by the bind helper
-- Any field or call answers another stand-in (hl.dsp.window.move({...}))
local any
any = setmetatable({}, { __index = function() return any end, __call = function() return any end })
hl = setmetatable({
    bind = function() end,
    unbind = function() end,
    define_submap = function() end,
}, { __index = function() return any end })
os.getenv = (function(getenv)
    return function(name)
        if name == "XDG_RUNTIME_DIR" then return os.tmpname():match("^(.*)/") end
        return getenv(name)
    end
end)(os.getenv)

require("conf/keybinds")
require("conf/specials")
lyne_specials_fallback()

local presets = require("conf/bind_presets")
local failures = 0
local function fail(msg)
    failures = failures + 1
    print("FAIL " .. msg)
end

-- Same order of modifiers as conf/binds.lua's normalize()
local mod_order = { SUPER = 1, CTRL = 2, CONTROL = 2, ALT = 3, SHIFT = 4 }
local function normalize(keys)
    local mods, key = {}, ""
    for raw in keys:gmatch("[^+]+") do
        local part = raw:match("^%s*(.-)%s*$"):upper()
        if mod_order[part] then
            table.insert(mods, part == "CONTROL" and "CTRL" or part)
        else
            key = part == "ENTER" and "RETURN" or part
        end
    end
    table.sort(mods, function(a, b) return mod_order[a] < mod_order[b] end)
    table.insert(mods, key)
    return table.concat(mods, "+")
end

-- Two actions on one key on purpose
local shared = { ["media-pause"] = true, ["media-play"] = true }

for name, preset in pairs(presets) do
    local keys = {}
    for _, entry in ipairs(LYNE_BINDS.list) do
        keys[entry.id] = entry.default
    end
    for id, combo in pairs(preset) do
        if id:sub(1, 1) ~= "_" then
            if keys[id] == nil then
                fail(name .. ": unknown bind id " .. id)
            end
            keys[id] = combo
        end
    end
    local seen = {}
    for id, combo in pairs(keys) do
        if combo ~= "" and not shared[id] then
            local n = normalize(combo)
            if seen[n] then
                fail(string.format("%s: %s and %s both on %s", name, seen[n], id, n))
            end
            seen[n] = id
        end
    end
end

assert(presets.komorebi, "komorebi preset missing")
assert(presets.komorebi._resize_step == 50, "komorebi resize step")
assert(presets.komorebi["toggle-split"] == "", "komorebi frees Super + Tab")

if failures > 0 then
    os.exit(1)
end
print("bind presets: ok")
