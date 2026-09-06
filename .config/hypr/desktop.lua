local core = require("desktop-core")
local M = {}
local runtime = os.getenv("XDG_RUNTIME_DIR")
local signature = os.getenv("HYPRLAND_INSTANCE_SIGNATURE")
local state_path = runtime and signature and (runtime .. "/dots-desktop-" .. signature .. ".lua")
local state = { bases = {}, windows = {}, modes = {}, bar_visible = false, bar_applied = false }
if state_path then
    local chunk = loadfile(state_path, "t", {})
    if chunk then
        local ok, saved = pcall(chunk)
        if ok and type(saved) == "table" and saved.version == 1 then state = saved end
    end
end
state.version = 1
local rebuilding = false
local reconciling = false
local workspace_rules = {}
local app_rules = {}
local history = {}
local normalize_pending = false
local topology = ""
local labels = {}
local label_directory = runtime and signature and (runtime .. "/dots-waybar-" .. signature)

local function publish_labels()
    if not label_directory then return end
    local changed = false
    for _, monitor in ipairs(hl.get_monitors()) do
        if monitor.name:match("^[%w_-]+$") then
            for number = 1, 9 do
                local ws = monitor.active_workspace
                local active = ws and core.logical(ws.id) == number
                local value = string.format('{"text":"%d","class":"%s","tooltip":"Workspace %d"}\n', number, active and "active" or "inactive", number)
                local path = label_directory .. "/" .. monitor.name .. "-" .. number .. ".json"
                if labels[path] ~= value then
                    local file = io.open(path .. ".tmp", "w")
                    if file then
                        file:write(value); file:close()
                        os.rename(path .. ".tmp", path)
                        labels[path] = value; changed = true
                    end
                end
            end
        end
    end
    if changed then hl.exec_cmd("pkill -RTMIN+9 -x waybar") end
end

local function serialize(value)
    if type(value) == "table" then
        local parts = {}
        for k, v in pairs(value) do
            parts[#parts + 1] = "[" .. serialize(k) .. "]=" .. serialize(v)
        end
        return "{" .. table.concat(parts, ",") .. "}"
    elseif type(value) == "string" then
        return string.format("%q", value)
    end
    return tostring(value)
end

local function save()
    if not state_path then return end
    local file = io.open(state_path .. ".tmp", "w")
    if not file then return end
    file:write("return ", serialize(state), "\n")
    file:close()
    os.rename(state_path .. ".tmp", state_path)
end

local function later(fn, delay)
    -- Hyprland's verifier emits config.reloaded without an event loop. Creating
    -- timers there crashes 0.56.2 during cleanup; it also has no live instance.
    if not signature then return end
    hl.timer(fn, { timeout = delay or 30, type = "oneshot" })
end

local function key(window)
    return tostring(window.stable_id)
end

local function meta(window)
    local id = key(window)
    state.windows[id] = state.windows[id] or {}
    return state.windows[id]
end

local function find(id)
    for _, window in ipairs(hl.get_windows()) do
        if key(window) == id then return window end
    end
end

local function float(window, enabled)
    if window and window.mapped and window.floating ~= enabled then
        hl.dispatch(hl.dsp.window.float({ window = window, action = enabled and "set" or "unset" }))
    end
end

local function active_workspace()
    return hl.get_active_workspace()
end

local function fallback_monitor(monitors)
    local active = hl.get_active_monitor()
    local names = core.connected(monitors)
    return active and names[active.name] and active.name or core.primary(monitors)
end

local function local_id(number, monitor)
    monitor = monitor or hl.get_active_monitor()
    if not monitor then return end
    core.assign_bases(state.bases, hl.get_monitors())
    return core.workspace(state.bases[monitor.name], number)
end

function M.view(number)
    local id = local_id(number)
    if id then hl.dispatch(hl.dsp.focus({ workspace = id })) end
end

function M.view_at_cursor(number)
    local monitor = hl.get_monitor_at_cursor() or hl.get_active_monitor()
    local id = local_id(number, monitor)
    if id then hl.dispatch(hl.dsp.focus({ workspace = id })) end
end

function M.browse(delta)
    local monitor = hl.get_active_monitor()
    local ws = monitor and monitor.active_workspace
    if ws then M.view(core.logical(ws.id) + delta) end
end

function M.move(number)
    local window = hl.get_active_window()
    if not window then return end
    local id = local_id(number, window.monitor)
    if id then hl.dispatch(hl.dsp.window.move({ window = window, workspace = id, follow = false })) end
end

local function tiled(ws)
    local windows = {}
    for _, window in ipairs(hl.get_windows({ workspace = ws })) do
        if not window.floating then windows[#windows + 1] = window end
    end
    return core.visual_order(windows)
end

local function capture_order(ws)
    local windows = tiled(ws)
    for i, window in ipairs(windows) do meta(window).order = i end
    return windows
end

local function ordered(ws)
    local windows = tiled(ws)
    table.sort(windows, function(a, b)
        local x, y = meta(a).order or math.huge, meta(b).order or math.huge
        return x < y or (x == y and a.stable_id < b.stable_id)
    end)
    return windows
end

-- Reinsert into native Dwindle in a known sequence. Native mouse resizing,
-- swaps, fullscreen and grouping remain compositor operations.
function M.rebuild(ws)
    ws = ws or active_workspace()
    if not ws or ws.special or ws.tiled_layout ~= "dwindle" or rebuilding then return end
    local windows = ordered(ws)
    if #windows == 0 then return end
    local focused = hl.get_active_window()
    local focused_id = focused and key(focused)
    local original_ws = active_workspace()
    local original_id = original_ws and original_ws.id
    rebuilding = true
    hl.dispatch(hl.dsp.focus({ workspace = ws }))
    for _, window in ipairs(windows) do float(window, true) end
    for i, window in ipairs(windows) do
        if i > 1 then
            hl.dispatch(hl.dsp.focus({ window = windows[i - 1] }))
            hl.dispatch(hl.dsp.layout("preselect " .. core.split_direction(i)))
        end
        float(window, false)
        meta(window).order = i
    end
    hl.dispatch(hl.dsp.layout("preselect none"))
    rebuilding = false
    if focused_id and find(focused_id) then
        hl.dispatch(hl.dsp.focus({ window = find(focused_id) }))
    elseif original_id then
        hl.dispatch(hl.dsp.focus({ workspace = original_id }))
    end
    save()
end

hl.layout.register("fair", {
    recalculate = function(ctx)
        local targets = ctx.targets
        table.sort(targets, function(a, b)
            local x = a.window and meta(a.window).order or a.index
            local y = b.window and meta(b.window).order or b.index
            x, y = x or math.huge, y or math.huge
            return x < y or (x == y and a.index < b.index)
        end)
        for i, target in ipairs(targets) do
            target:place(core.fair_cell(i, #ctx.targets, ctx.area))
        end
    end,
})

function M.cycle_layout()
    local ws = active_workspace()
    if not ws or ws.special then return end
    local mode = state.modes[ws.id] or ws.tiled_layout
    local next_mode = ({ dwindle = "master", master = "lua:fair", ["lua:fair"] = "floating", floating = "dwindle" })[mode] or "dwindle"
    if mode == "dwindle" then capture_order(ws) end
    state.modes[ws.id] = next_mode
    if next_mode == "floating" then
        for _, window in ipairs(tiled(ws)) do
            meta(window).layout_float = true
            float(window, true)
        end
    else
        hl.workspace_rule({ workspace = tostring(ws.id), layout = next_mode })
        -- Rule refresh is deferred by Hyprland until after this callback.
        later(function()
            if mode == "floating" then
                for _, window in ipairs(hl.get_windows({ workspace = ws })) do
                    if meta(window).layout_float then
                        meta(window).layout_float = nil
                        if not meta(window).ontop then float(window, false) end
                    end
                end
            end
            if next_mode == "dwindle" then M.rebuild(ws) end
            save()
        end)
    end
    save()
end

function M.swap(delta)
    local ws, active = active_workspace(), hl.get_active_window()
    if not ws or not active then return end
    if ws.tiled_layout == "lua:fair" then
        local windows = ordered(ws)
        for i, window in ipairs(windows) do
            if window == active then
                local other = windows[((i - 1 + delta) % #windows) + 1]
                local a, b = meta(window), meta(other)
                a.order, b.order = b.order, a.order
                hl.dispatch(hl.dsp.layout("recalculate"))
                save()
                return
            end
        end
    else
        hl.dispatch(hl.dsp.window.swap(delta > 0 and { next = true } or { prev = true }))
        later(function() capture_order(ws); save() end)
    end
end

function M.resize(delta)
    local ws = active_workspace()
    if not ws or state.modes[ws.id] == "floating" then return end
    if ws.tiled_layout == "dwindle" then
        hl.dispatch(hl.dsp.layout("splitratio " .. delta))
    elseif ws.tiled_layout == "master" then
        hl.dispatch(hl.dsp.layout("mfact " .. delta))
    end
end

function M.toggle_sticky()
    local window = hl.get_active_window()
    if not window then return end
    local data = meta(window)
    data.sticky = not data.sticky or nil
    data.monitor = window.monitor.name
    if window.pinned then hl.dispatch(hl.dsp.window.pin({ window = window, action = "unset" })) end
    save()
end

function M.toggle_ontop()
    local window = hl.get_active_window()
    if not window then return end
    local data = meta(window)
    if data.ontop then
        data.ontop = nil
        float(window, data.was_floating or data.layout_float or data.magnified ~= nil)
        data.was_floating = nil
    else
        data.was_floating = window.floating
        if data.magnified then data.was_floating = data.magnified.floating end
        data.ontop = true
        float(window, true)
        hl.dispatch(hl.dsp.window.alter_zorder({ window = window, mode = "top" }))
    end
    save()
end

local function reassert_top()
    for _, window in ipairs(hl.get_windows()) do
        if meta(window).ontop and not meta(window).minimized then
            hl.dispatch(hl.dsp.window.alter_zorder({ window = window, mode = "top" }))
        end
    end
end

local function previous_focus(ws_id)
    local ws = active_workspace()
    if not ws or ws.id ~= ws_id then return end
    for _, id in ipairs(history[ws_id] or {}) do
        local window = find(id)
        if window and window.workspace and window.workspace.id == ws_id and not meta(window).minimized then
            hl.dispatch(hl.dsp.focus({ window = window }))
            return
        end
    end
end

function M.minimize()
    local window = hl.get_active_window()
    local ws = window and window.workspace
    if not ws or ws.special then return end
    state.sequence = (state.sequence or 0) + 1
    local data = meta(window)
    data.minimized, data.restore_ws = state.sequence, ws.id
    hl.dispatch(hl.dsp.window.move({ window = window, workspace = "special:minimized", follow = false }))
    save()
    later(function() previous_focus(ws.id) end)
end

local function restore(window)
    local data = meta(window)
    local monitors = hl.get_monitors()
    local fallback = fallback_monitor(monitors)
    if not fallback then return end
    local id = core.destination(state.bases, monitors, data.restore_ws or local_id(1), fallback)
    data.minimized, data.restore_ws = nil, nil
    hl.dispatch(hl.dsp.window.move({ window = window, workspace = id, follow = true }))
    hl.dispatch(hl.dsp.focus({ window = window }))
    save()
end

function M.restore()
    local latest, sequence
    for _, window in ipairs(hl.get_windows()) do
        local data = meta(window)
        if data.minimized and (not sequence or data.minimized > sequence) then
            latest, sequence = window, data.minimized
        end
    end
    if latest then restore(latest) end
end

function M.focus_window(address)
    for _, window in ipairs(hl.get_windows()) do
        if window.address == address then
            if meta(window).minimized then restore(window) else hl.dispatch(hl.dsp.focus({ window = window })) end
            hl.dispatch(hl.dsp.window.bring_to_top({ window = window }))
            return
        end
    end
end

local function sync_bar()
    local fullscreen = {}
    for _, window in ipairs(hl.get_windows()) do
        if window.fullscreen == 2 and window.workspace and window.monitor
            and window.monitor.active_workspace == window.workspace then fullscreen[#fullscreen + 1] = key(window) end
    end
    table.sort(fullscreen)
    local fullscreen_key = table.concat(fullscreen, ",")
    if fullscreen_key ~= state.bar_fullscreen_key then
        state.bar_fullscreen_key = fullscreen_key
        state.bar_override = nil
    end
    local visible = state.bar_visible and (#fullscreen == 0 or state.bar_override == true)
    if visible ~= state.bar_applied then
        hl.exec_cmd("pkill -SIGUSR1 -x waybar")
        state.bar_applied = visible
        save()
    end
end

function M.toggle_bar()
    -- Toggle what is actually visible. An automatic fullscreen hide must not
    -- make the user's explicit toggle ineffective (including on other screens).
    sync_bar()
    state.bar_visible = not state.bar_applied
    state.bar_override = true
    sync_bar()
    save()
end

function M.bar_restarted()
    state.bar_applied = false
    sync_bar()
end

function M.magnify()
    local window = hl.get_active_window()
    if not window then return end
    local data = meta(window)
    if data.magnified then
        float(window, data.magnified.floating or data.ontop or data.layout_float or false)
        if data.magnified.floating then
            hl.dispatch(hl.dsp.window.resize({ window = window, x = data.magnified.w, y = data.magnified.h }))
            hl.dispatch(hl.dsp.window.move({ window = window, x = data.magnified.x, y = data.magnified.y }))
        end
        data.magnified = nil
    else
        data.magnified = { floating = window.floating, x = window.at.x, y = window.at.y, w = window.size.x, h = window.size.y }
        if data.ontop then data.magnified.floating = data.was_floating end
        float(window, true)
        local monitor = window.monitor
        local width = monitor.width / monitor.scale
        local height = monitor.height / monitor.scale - (state.bar_applied and 32 or 0)
        hl.dispatch(hl.dsp.window.resize({ window = window, x = math.floor(width * math.sqrt(0.5)), y = math.floor(height * math.sqrt(0.5)) }))
        hl.dispatch(hl.dsp.window.center({ window = window }))
    end
    save()
end

local apps = {
    { "[Cc]ode", 1 }, { "[Ff]irefox", 2 }, { "[Aa]lacritty", 3 },
    { "[Nn]emo", 4 }, { "[Dd]iscord", 5 }, { "[Ss]potify", 6 },
    { "(org\\.keepassxc\\.KeePassXC|[Kk]ee[Pp]ass[Xx][Cc])", 7 }, { "[Ss]team", 8 },
}

function M.reconcile()
    if reconciling then return end
    local monitors = hl.get_monitors()
    local fallback = fallback_monitor(monitors)
    if not fallback then return end
    reconciling = true
    local focused = hl.get_active_window()
    local focused_id = focused and key(focused)
    local names = core.connected(monitors)
    core.assign_bases(state.bases, monitors)
    local monitor_names = {}
    for name in pairs(names) do monitor_names[#monitor_names + 1] = name end
    table.sort(monitor_names)
    local new_topology = table.concat(monitor_names, ",")
    if new_topology ~= topology then
        topology = new_topology
        for _, rule in ipairs(workspace_rules) do rule:set_enabled(false) end
        workspace_rules = {}
        for name, base in pairs(state.bases) do
            for i = 1, 9 do
                local id = base + i
                workspace_rules[#workspace_rules + 1] = hl.workspace_rule({
                    workspace = tostring(id), monitor = names[name] and name or fallback,
                    persistent = names[name] or false,
                    layout = state.modes[id] == "floating" and "dwindle" or state.modes[id] or "dwindle",
                })
            end
        end
        for _, rule in ipairs(app_rules) do rule:set_enabled(false) end
        app_rules = {}
        local primary = core.primary(monitors, fallback)
        for _, app in ipairs(apps) do
            app_rules[#app_rules + 1] = hl.window_rule({ match = { initial_class = app[1] }, workspace = tostring(state.bases[primary] + app[2]) })
        end
    end
    for _, window in ipairs(hl.get_windows()) do
        local data = meta(window)
        if data.restore_ws then data.restore_ws = core.destination(state.bases, monitors, data.restore_ws, fallback) end
        if data.monitor and not names[data.monitor] then data.monitor = fallback end
        local ws = window.workspace
        if ws and not ws.special then
            local destination = core.destination(state.bases, monitors, ws.id, fallback)
            if destination ~= ws.id then
                hl.dispatch(hl.dsp.window.move({ window = window, workspace = destination, follow = false }))
            end
        elseif ws and ws.name:match("minimized$") and not data.minimized then
            state.sequence = (state.sequence or 0) + 1
            data.minimized, data.restore_ws = state.sequence, local_id(1)
        end
    end
    if focused_id and find(focused_id) then hl.dispatch(hl.dsp.focus({ window = find(focused_id) })) end
    -- No active monitor may stay on a compositor-created workspace 10/20/etc.
    for _, monitor in ipairs(monitors) do
        local ws = monitor.active_workspace
        if ws and (core.owner(state.bases, ws.id) ~= monitor.name) then
            local id = local_id(core.logical(ws.id), monitor)
            hl.dispatch(hl.dsp.focus({ workspace = id }))
        end
    end
    reconciling = false
    publish_labels()
    save()
end

local function schedule_reconcile()
    if normalize_pending or reconciling then return end
    normalize_pending = true
    later(function() normalize_pending = false; M.reconcile() end, 100)
end

function M.setup()
    if label_directory then
        os.execute("mkdir -p " .. string.format("%q", label_directory))
    end
    hl.on("hyprland.start", schedule_reconcile)
    hl.on("config.reloaded", schedule_reconcile)
    hl.on("monitor.added", schedule_reconcile)
    hl.on("monitor.removed", schedule_reconcile)
    hl.on("workspace.created", schedule_reconcile)
    hl.on("window.move_to_workspace", function(window)
        if window and window.monitor and meta(window).sticky then
            meta(window).monitor = window.monitor.name
        end
        schedule_reconcile()
    end)
    hl.on("window.open", function(window)
        local ws = window.workspace
        if ws and state.modes[ws.id] == "floating" and not window.floating then
            meta(window).layout_float = true
            float(window, true)
        end
        if ws and ws.tiled_layout == "dwindle" and state.modes[ws.id] ~= "floating" and not window.floating then
            local id = key(window)
            later(function()
                if find(id) then M.rebuild(ws) end
            end)
        end
        reassert_top()
        save()
    end)
    hl.on("window.active", function(window)
        if not rebuilding and window and window.workspace and not window.workspace.special then
            local list = history[window.workspace.id] or {}
            local id = key(window)
            for i = #list, 1, -1 do if list[i] == id then table.remove(list, i) end end
            table.insert(list, 1, id)
            history[window.workspace.id] = list
        end
        reassert_top()
        publish_labels()
    end)
    hl.on("window.urgent", function(window)
        if window and not meta(window).minimized then hl.dispatch(hl.dsp.focus({ window = window })) end
    end)
    hl.on("workspace.active", function(ws)
        if rebuilding or reconciling or not ws or ws.special then return end
        for _, window in ipairs(hl.get_windows()) do
            local data = meta(window)
            if data.sticky and not data.minimized and ws.monitor and data.monitor == ws.monitor.name
                and window.workspace ~= ws then
                hl.dispatch(hl.dsp.window.move({ window = window, workspace = ws, follow = false }))
            end
        end
        sync_bar()
        publish_labels()
    end)
    hl.on("window.fullscreen", function() later(sync_bar) end)
    hl.on("window.close", function(window)
        local ws = window.workspace
        state.windows[key(window)] = nil
        later(function()
            if ws then previous_focus(ws.id) end
            sync_bar()
            save()
        end)
    end)
    local function gesture(fingers, direction, action)
        hl.gesture({ fingers = fingers, direction = direction, action = function(event)
            if not event or not event.cancelled then action() end
        end })
    end
    gesture(3, "left", function() M.browse(1) end)
    gesture(3, "right", function() M.browse(-1) end)
    gesture(3, "up", M.restore)
    gesture(3, "down", M.minimize)
    gesture(4, "left", function() hl.dispatch(hl.dsp.window.cycle_next({ next = false })) end)
    gesture(4, "right", function() hl.dispatch(hl.dsp.window.cycle_next({ next = true })) end)
    gesture(4, "up", M.magnify)
    gesture(4, "down", M.magnify)
    local function initialize()
        M.reconcile()
        local live = {}
        for _, window in ipairs(hl.get_windows()) do live[key(window)] = true end
        for id in pairs(state.windows) do if not live[id] then state.windows[id] = nil end end
        for _, ws in ipairs(hl.get_workspaces()) do
            if not ws.special and ws.tiled_layout == "dwindle" and state.modes[ws.id] ~= "floating" then capture_order(ws) end
        end
        reassert_top()
        sync_bar()
        save()
    end
    -- Queries require a running compositor; --verify-config has no monitor state.
    hl.on("hyprland.start", function() later(initialize, 150) end)
    hl.on("config.reloaded", function() later(initialize, 150) end)
end

return M
