-- Run from the repository root: lua scripts/check-desktop.lua
package.path = "./.config/hypr/?.lua;" .. package.path
local core = require("desktop-core")
local function eq(actual, expected)
    assert(actual == expected, tostring(actual) .. " ~= " .. tostring(expected))
end

local bases = {}
local external = { name = "DP-4" }
local laptop = { name = "eDP-1" }
core.assign_bases(bases, { external, laptop })
eq(core.workspace(bases[external.name], 10), 1)
eq(core.workspace(bases[laptop.name], 0), 19)
for n = 1, 9 do
    eq(core.logical(n), n)
    eq(core.logical(10 + n), n)
    eq(core.destination(bases, { laptop }, n, laptop.name), 10 + n)
    eq(core.destination(bases, { external }, 10 + n, external.name), n)
    eq(core.destination(bases, { external, laptop }, n, laptop.name), n)
end
eq(core.destination(bases, { laptop }, 20, laptop.name), 11)
eq(core.primary({ external, laptop }), "DP-4")
eq(core.primary({ laptop }), "eDP-1")
for n = 2, 9 do eq(core.split_direction(n), n % 2 == 0 and "right" or "down") end

-- Fair fills the entire work area with non-overlapping cells, including an
-- incomplete final column. A 9-window workspace is exactly a 3x3 grid.
for count = 1, 12 do
    local area, cells, total = { x = 20, y = 30, w = 1200, h = 900 }, {}, 0
    for i = 1, count do
        local box = core.fair_cell(i, count, area)
        assert(box.x >= area.x and box.y >= area.y)
        assert(box.x + box.w <= area.x + area.w + 0.001)
        assert(box.y + box.h <= area.y + area.h + 0.001)
        for _, other in ipairs(cells) do
            assert(box.x + box.w <= other.x + 0.001 or other.x + other.w <= box.x + 0.001
                or box.y + box.h <= other.y + 0.001 or other.y + other.h <= box.y + 0.001)
        end
        cells[#cells + 1] = box
        total = total + box.w * box.h
        if count == 9 then eq(box.w, 400); eq(box.h, 300) end
    end
    assert(math.abs(total - area.w * area.h) < 0.01)
end

-- Exercise callbacks against a small compositor model. This checks state
-- interactions and hot-unplug policy; actual tiling/clicks are tested live.
local original_getenv = os.getenv
os.getenv = function(name)
    if name == "HYPRLAND_INSTANCE_SIGNATURE" then return "desktop-unit-test" end
    if name == "XDG_RUNTIME_DIR" then return nil end
    return original_getenv(name)
end
local monitors = { external, laptop }
local workspaces, windows, events, timers, commands = {}, {}, {}, {}, {}
local bar_signals = 0
local active_monitor, active_window = external, nil
for _, mon in ipairs(monitors) do
    mon.width, mon.height, mon.scale = 2560, 1600, 1
    for n = 1, 9 do
        local id = bases[mon.name] + n
        workspaces[id] = { id = id, name = tostring(id), monitor = mon, tiled_layout = "dwindle", special = false }
    end
    mon.active_workspace = workspaces[bases[mon.name] + 1]
end
local function emit(name, ...)
    for _, callback in ipairs(events[name] or {}) do callback(...) end
end
local function flush()
    local count = 0
    while #timers > 0 do
        local pending = timers; timers = {}
        for _, fn in ipairs(pending) do fn() end
        count = count + 1
        assert(count < 20, "callback loop")
    end
end
local function window(id, workspace)
    local w = { stable_id = id, address = string.format("0x%x", id), workspace = workspaces[workspace],
        monitor = workspaces[workspace].monitor, mapped = true, floating = false, fullscreen = 0,
        at = { x = id * 20, y = id * 30 }, size = { x = 600, y = 600 } }
    windows[#windows + 1] = w
    return w
end
local function dispatcher(name)
    return function(options)
        return function()
            commands[#commands + 1] = { name = name, options = options }
            local w = type(options) == "table" and options.window or active_window
            if name == "focus" then
                if options.window then active_window = options.window; active_monitor = active_window.monitor; active_monitor.active_workspace = active_window.workspace
                elseif options.workspace then
                    local ws = type(options.workspace) == "table" and options.workspace or workspaces[tonumber(options.workspace)]
                    assert(ws, "unknown focus workspace")
                    active_monitor = ws.monitor; active_monitor.active_workspace = ws
                end
            elseif name == "float" then w.floating = options.action == "set"
            elseif name == "move" and options.workspace then
                if options.workspace == "special:minimized" then
                    w.workspace = { id = -99, name = "special:minimized", special = true }
                else
                    w.workspace = type(options.workspace) == "table" and options.workspace or workspaces[tonumber(options.workspace)]
                    w.monitor = w.workspace.monitor
                end
            end
        end
    end
end
hl = {
    get_monitors = function() return monitors end,
    get_active_monitor = function() return active_monitor end,
    get_monitor_at_cursor = function() return active_monitor end,
    get_active_workspace = function() return active_monitor.active_workspace end,
    get_active_window = function() return active_window end,
    get_workspaces = function() local result = {}; for _, w in pairs(workspaces) do result[#result + 1] = w end; return result end,
    get_windows = function(filter)
        local result = {}
        for _, w in ipairs(windows) do
            if w.mapped and (not filter or not filter.workspace or w.workspace == filter.workspace) then result[#result + 1] = w end
        end
        return result
    end,
    on = function(name, fn) events[name] = events[name] or {}; table.insert(events[name], fn) end,
    timer = function(fn) timers[#timers + 1] = fn end,
    exec_cmd = function(command) if command == "pkill -SIGUSR1 -x waybar" then bar_signals = bar_signals + 1 end end,
    gesture = function() end,
    layout = { register = function() end },
    dispatch = function(fn) return fn() end,
    workspace_rule = function(rule)
        local ws = workspaces[tonumber(rule.workspace)]
        if ws and rule.layout then ws.tiled_layout = rule.layout end
        return { set_enabled = function() end }
    end,
    window_rule = function() return { set_enabled = function() end } end,
    dsp = { focus = dispatcher("focus"), layout = dispatcher("layout"), window = setmetatable({}, { __index = function(_, name) return dispatcher(name) end }) },
}
local desktop = require("desktop")
desktop.setup()
emit("hyprland.start"); flush()
local a, b = window(1, 3), window(2, 13)
active_window, active_monitor = a, external
external.active_workspace = workspaces[3]
desktop.toggle_sticky(); desktop.toggle_ontop()
assert(a.floating)
desktop.toggle_ontop(); assert(not a.floating)
emit("workspace.active", workspaces[4]); eq(a.workspace.id, 4) -- Sticky survived ontop.
desktop.toggle_sticky()
desktop.minimize(); assert(a.workspace.special)
monitors = { laptop }; active_monitor = laptop; active_window = b
desktop.reconcile()
desktop.restore(); eq(a.workspace.id, 14) -- Saved destination merged on disconnect.
active_window = b
desktop.minimize()
active_window = a
desktop.minimize()
desktop.restore(); eq(a.workspace.id, 14)
desktop.restore(); eq(b.workspace.id, 13)
active_window = a; active_monitor = laptop; laptop.active_workspace = workspaces[14]
desktop.cycle_layout(); flush(); eq(workspaces[14].tiled_layout, "master")
desktop.cycle_layout(); flush(); eq(workspaces[14].tiled_layout, "lua:fair")
desktop.cycle_layout(); flush(); assert(a.floating)
desktop.cycle_layout(); flush(); assert(not a.floating); eq(workspaces[14].tiled_layout, "dwindle")
desktop.magnify(); desktop.toggle_ontop(); desktop.magnify()
assert(a.floating, "ontop must survive ending magnification")
desktop.toggle_ontop(); assert(not a.floating)
desktop.toggle_ontop(); desktop.magnify(); desktop.toggle_ontop()
assert(a.floating, "magnification must survive ending ontop")
desktop.magnify(); assert(not a.floating)
local before_signals = bar_signals
desktop.toggle_bar(); eq(bar_signals, before_signals + 1)
a.fullscreen = 2
emit("window.fullscreen", a); flush(); eq(bar_signals, before_signals + 2)
desktop.toggle_bar(); eq(bar_signals, before_signals + 3) -- Explicit show over fullscreen.
desktop.toggle_bar(); eq(bar_signals, before_signals + 4)
a.fullscreen = 0
emit("window.fullscreen", a); flush(); eq(bar_signals, before_signals + 4) -- Manual hide survives.
print("Desktop policy and state tests passed")
