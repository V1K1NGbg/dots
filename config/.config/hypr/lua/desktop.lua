local core = require("lua.desktop-core")
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
state.merges = state.merges or {}
local rebuilding = false
local reconciling = false
local merging = false
local workspace_rules = {}
local app_rules = {}
local history = {}
local normalize_pending = false
local rebuild_pending = {}
local rebuild_deferred = {}
local mouse_active = false
local mouse_window
local topology = ""
local labels = {}
local label_directory = runtime and signature and (runtime .. "/dots-waybar-" .. signature)

local function publish_labels()
    if not label_directory then return end
    local changed = false
    for _, monitor in ipairs(hl.get_monitors()) do
        if monitor.name:match("^[%w_-]+$") then
            local ws = monitor.active_workspace
            local merged = {}
            if ws then
                for home, host in pairs(state.merges) do
                    if host == ws.id then merged[core.logical(home)] = true end
                end
            end
            for number = 1, 9 do
                local active = ws and (core.logical(ws.id) == number or merged[number])
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
    if changed then hl.exec_cmd("bash ~/.config/hypr/scripts/waybar.sh refresh") end
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

-- A plain (single-stop) border color, as a config string; nil for anything
-- the mask cannot round-trip, which simply leaves it off.
local function border_color(name)
    local colors = hl.get_config(name).colors
    local argb = colors and #colors == 1 and tonumber(colors[1])
    if not argb then return end
    return string.format("rgba(%06X%02X)", argb & 0xFFFFFF, argb >> 24)
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

-- Move the pointer to a window's midpoint. Guarded so closing or hidden
-- windows cannot pull the cursor to a stale rectangle.
local function center_cursor_on(window)
    if not window or not window.mapped or not window.monitor then return end
    local at, size = window.at, window.size
    if not at or not size or size.x <= 0 or size.y <= 0 then return end
    hl.dispatch(hl.dsp.cursor.move({ x = at.x + size.x / 2, y = at.y + size.y / 2 }))
end

-- Desktop::eFocusReason is a bitmask. Mouse-driven focus (FFM, click) must
-- not warp the cursor; the pointer is already where it caused the focus.
local MOUSE_FOCUS_REASONS = 1 | 16

local function float(window, enabled)
    if window and window.mapped and window.floating ~= enabled then
        hl.dispatch(hl.dsp.window.float({ window = window, action = enabled and "set" or "unset" }))
    end
end

local function active_workspace()
    return hl.get_active_workspace()
end

local function fallback_monitor(monitors)
    if core.connected(monitors)[state.primary] then return state.primary end
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

-- Hyprland fades a window out when it silently leaves a visible workspace,
-- but only when the destination is empty: moving into an occupied one
-- re-tiles the window and the fade is skipped, so it vanishes in one step.
-- Parking the window on a private special workspace for the duration of the
-- fade and hopping it to the real destination afterwards keeps the
-- animation on every move. The second hop happens while the window is
-- already invisible, so nothing more animates there.
function M.move(number)
    local window = hl.get_active_window()
    if not window then return end
    local id = local_id(number, window.monitor)
    if not id then return end
    local id_key = key(window)
    local data = meta(window)
    data.hop = id
    hl.dispatch(hl.dsp.window.move({ window = window, workspace = "special:dots-fadehop", follow = false }))
    later(function()
        if data.hop ~= id then return end
        data.hop = nil
        -- Anything the user did with the window while it was fading
        -- (minimize, another move, closing it) must not be undone.
        local current = find(id_key)
        local ws = current and current.workspace
        if ws and ws.special and ws.name:match("fadehop$") then
            hl.dispatch(hl.dsp.window.move({ window = current, workspace = id, follow = false }))
        end
    end, 500)
end

local function workspace_visible(id)
    for _, monitor in ipairs(hl.get_monitors()) do
        local ws = monitor.active_workspace
        if ws and ws.id == id then return true end
    end
    return false
end

local function unmerge(predicate)
    local count = 0
    merging = true
    for _, window in ipairs(hl.get_windows()) do
        local data = state.windows[key(window)]
        if data and data.merged_into and predicate(data) then
            local home = data.home_ws
            data.home_ws, data.merged_into = nil, nil
            count = count + 1
            if home and window.mapped then
                hl.dispatch(hl.dsp.window.move({ window = window, workspace = home, follow = false }))
            end
        end
    end
    merging = false
    return count
end

-- Awesome's viewtoggle: pull another workspace's windows onto the active one.
-- state.merges[home] = host tracks the merge even while the home has no
-- windows; per-window home_ws/merged_into returns each window when it ends.
function M.toggle_co_view(number)
    local active = active_workspace()
    if not active or active.special then return end
    local id = local_id(number)
    if not id or id == active.id then return end
    if state.merges[id] == active.id then
        state.merges[id] = nil
        unmerge(function(data) return data.merged_into == active.id and data.home_ws == id end)
    else
        state.merges[id] = nil
        unmerge(function(data) return data.home_ws == id end)
        merging = true
        local target = hl.get_workspace(id)
        if target then
            for _, window in ipairs(hl.get_windows({ workspace = target })) do
                if window.mapped then
                    hl.dispatch(hl.dsp.window.move({ window = window, workspace = active.id, follow = false }))
                    local data = meta(window)
                    data.home_ws, data.merged_into = id, active.id
                end
            end
        end
        state.merges[id] = active.id
        merging = false
    end
    publish_labels()
    save()
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
    for i, window in ipairs(windows) do
        local data = meta(window)
        data.order, data.order_workspace = i, ws.id
    end
    return windows
end

local function ordered(ws)
    local windows = tiled(ws)
    table.sort(windows, function(a, b)
        local x, y = meta(a).order or math.huge, meta(b).order or math.huge
        if x ~= y then return x < y end
        x, y = meta(a).arrival_order or math.huge, meta(b).arrival_order or math.huge
        return x < y or (x == y and a.stable_id < b.stable_id)
    end)
    for i, window in ipairs(windows) do
        local data = meta(window)
        data.order, data.order_workspace = i, ws.id
        data.arrival_order = nil
    end
    return windows
end

-- Reinsert into native Dwindle in a known sequence. Native mouse resizing,
-- swaps, fullscreen and grouping remain compositor operations.
function M.rebuild(ws)
    ws = ws or active_workspace()
    if not ws or ws.special or ws.tiled_layout ~= "dwindle" or rebuilding or mouse_active then return end
    local windows = ordered(ws)
    -- One window cannot be out of order; rebuilding it only flickers.
    if #windows < 2 then return end
    -- The common cases are already in order: a new window splits the focused,
    -- visually last one, and a removed window's siblings inherit boxes that
    -- keep the reading order. But a removal can also re-lay the sibling subtree
    -- out into a shape the rebuild would not produce, which reads as a wrong
    -- order. Only skip when the sequence matches AND the rectangles still form
    -- the canonical chain; otherwise re-tiling also cycles keyboard focus
    -- through every window, which reads as quick focus swaps.
    local settled = tiled(ws)
    local unchanged = #settled == #windows
    if unchanged then
        for i = 1, #windows do
            if key(windows[i]) ~= key(settled[i]) then unchanged = false; break end
        end
    end
    if unchanged and core.canonical_chain(settled) then save(); return end
    local focused = hl.get_active_window()
    local focused_id = focused and key(focused)
    local original_ws = active_workspace()
    local original_id = original_ws and original_ws.id
    rebuilding = true
    -- Focus drives Dwindle insertion (use_active_for_splits), so re-tiling
    -- cycles keyboard focus across every window, repainting the active border
    -- on each one. Equal borders hide the whole cycle; the final focus is
    -- restored before the real color returns, leaving one visible transition.
    local active_color = border_color("general:col.active_border")
    local inactive_color = border_color("general:col.inactive_border")
    local masked = active_color and inactive_color and active_color ~= inactive_color
    if masked then
        hl.config({ general = { col = { active_border = inactive_color } } })
    end
    local ok, err = pcall(function()
        hl.dispatch(hl.dsp.focus({ workspace = ws }))
        for _, window in ipairs(windows) do float(window, true) end
        for i, window in ipairs(windows) do
            if i > 1 then
                hl.dispatch(hl.dsp.focus({ window = windows[i - 1] }))
                hl.dispatch(hl.dsp.layout("preselect " .. core.split_direction(i)))
            end
            float(window, false)
        end
        hl.dispatch(hl.dsp.layout("preselect none"))
    end)
    rebuilding = false
    if focused_id and find(focused_id) then
        hl.dispatch(hl.dsp.focus({ window = find(focused_id) }))
    elseif original_id then
        hl.dispatch(hl.dsp.focus({ workspace = original_id }))
    end
    if masked then
        hl.config({ general = { col = { active_border = active_color } } })
    end
    if not ok then error(err) end
    save()
end

-- Rebuilding a hidden workspace would steal focus to re-tile it, flashing the
-- screen on every move or merge. Defer until the workspace is actually shown.
local function schedule_rebuild(id)
    if not id or id <= 0 or rebuilding or rebuild_pending[id] then return end
    if not workspace_visible(id) then
        rebuild_deferred[id] = true
        return
    end
    rebuild_pending[id] = true
    -- Moves and workspace rules settle after their event callback. Batch a
    -- dock/undock burst and resolve the workspace again; it may be gone by then.
    later(function()
        rebuild_pending[id] = nil
        if mouse_active then schedule_rebuild(id); return end
        if not workspace_visible(id) then rebuild_deferred[id] = true; return end
        local ws = hl.get_workspace(id)
        if ws then M.rebuild(ws) end
    end, 150)
end

function M.mouse(action)
    -- Native mouse dispatchers request a second invocation on button release.
    -- Keep using that lifecycle, but postpone repairs until the drag has ended.
    if mouse_active then
        local window = mouse_window
        hl.dispatch(hl.dsp.window[action]())
        mouse_active, mouse_window = false, nil
        if action == "drag" then
            if window and window.mapped and not window.floating and window.workspace then
                capture_order(window.workspace)
            end
            -- After a drag completes, the pointer sits wherever it was
            -- released. Re-center it on the window so subsequent clicks
            -- land on the moved client.
            center_cursor_on(window)
        end
    else
        mouse_active = true
        mouse_window = hl.get_active_window()
        if action == "drag" and mouse_window and not mouse_window.floating and mouse_window.workspace then
            schedule_rebuild(mouse_window.workspace.id)
        end
        hl.dispatch(hl.dsp.window[action]())
    end
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
            if target.window and target.window.workspace then
                local data = meta(target.window)
                data.order, data.order_workspace = i, target.window.workspace.id
            end
            target:place(core.fair_cell(i, #ctx.targets, ctx.area))
        end
    end,
})

function M.cycle_layout()
    local ws = active_workspace()
    if not ws or ws.special then return end
    local mode = state.modes[ws.id] or ws.tiled_layout
    local next_mode = ({ dwindle = "master", master = "lua:fair", ["lua:fair"] = "dwindle" })[mode] or "dwindle"
    if mode == "dwindle" then capture_order(ws) end
    state.modes[ws.id] = next_mode
    hl.workspace_rule({ workspace = tostring(ws.id), layout = next_mode })
    -- Rule refresh is deferred by Hyprland until after this callback.
    later(function()
        if next_mode == "dwindle" then M.rebuild(ws) end
        save()
    end)
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
    if not ws then return end
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
        float(window, data.was_floating or data.magnified ~= nil)
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
        hl.exec_cmd("bash ~/.config/hypr/scripts/waybar.sh " .. (visible and "show" or "hide"))
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
        float(window, data.magnified.floating or data.ontop or false)
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
    -- Hyprland rules use regex; place_apps needs Lua patterns (% escapes, no
    -- alternation), listed per entry as the optional third element.
    { "(com\\.microsoft\\.VSCode|[Cc]ode)", 1, { "^com%.microsoft%.VSCode$", "^[Cc]ode$" } },
    { "[Ff]irefox", 2 }, { "[Aa]lacritty", 3 },
    { "[Nn]emo", 4 }, { "[Dd]iscord", 5 }, { "[Ss]potify", 6 },
    { "(org\\.keepassxc\\.KeePassXC|[Kk]ee[Pp]ass[Xx][Cc])", 7, { "^org%.keepassxc%.KeePassXC$", "^[Kk]ee[Pp]ass[Xx][Cc]$" } },
    { "[Ss]team", 8 },
}

local function app_number(class)
    for _, app in ipairs(apps) do
        if app[3] then
            for _, pattern in ipairs(app[3]) do
                if class:match(pattern) then return app[2] end
            end
        elseif class:match(app[1]) then
            return app[2]
        end
    end
end

-- Return known apps to their dedicated workspaces on the primary screen.
-- Window rules only place new windows; a config reload calls this to repair
-- the ones already open.
function M.place_apps()
    local monitors = hl.get_monitors()
    local names = core.connected(monitors)
    local fallback = fallback_monitor(monitors)
    if not fallback then return end
    core.assign_bases(state.bases, monitors)
    local primary = names[state.primary] and state.primary or core.primary(monitors, fallback)
    for _, window in ipairs(hl.get_windows()) do
        local class = window.initial_class
        if not class or class == "" then class = window.class end
        local number = class and app_number(class)
        if number then
            local ws = window.workspace
            local target = core.workspace(state.bases[primary], number)
            if window.mapped and ws and not ws.special and ws.id ~= target then
                hl.dispatch(hl.dsp.window.move({ window = window, workspace = target, follow = false }))
            end
        end
    end
end

-- Called once after a display profile is applied, never on ordinary workspace
-- changes. Users can still move windows back to the secondary screen.
function M.set_primary(name, gather)
    local monitors = hl.get_monitors()
    if not core.connected(monitors)[name] then return end
    state.primary = name
    topology = ""
    M.reconcile()
    if gather then
        local focused = hl.get_active_window()
        for _, window in ipairs(hl.get_windows()) do
            local data = meta(window)
            if data.restore_ws then
                data.restore_ws = core.workspace(state.bases[name], core.logical(data.restore_ws))
            end
            if data.monitor then data.monitor = name end
            local ws = window.workspace
            if ws and not ws.special then
                local destination = core.workspace(state.bases[name], core.logical(ws.id))
                if destination ~= ws.id then
                    hl.dispatch(hl.dsp.window.move({ window = window, workspace = destination, follow = false }))
                end
            end
        end
        if focused and focused.mapped and not meta(focused).minimized then
            hl.dispatch(hl.dsp.focus({ window = focused }))
        else
            hl.dispatch(hl.dsp.focus({ monitor = name }))
        end
    end
    save()
end

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
    local remapped = {}
    for home, host in pairs(state.merges or {}) do
        local new_home = core.destination(state.bases, monitors, home, fallback)
        local new_host = core.destination(state.bases, monitors, host, fallback)
        -- Drop zombie records whose host is hidden and remap collisions.
        if new_home ~= new_host and workspace_visible(new_host) then
            remapped[new_home] = new_host
        end
    end
    state.merges = remapped
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
                    -- Labels already expose all nine logical workspaces. Waybar
                    -- 0.15 imports persistent rules without ignore-workspaces,
                    -- duplicating every taskbar in every group on cold startup.
                    persistent = false,
                    layout = state.modes[id] or "dwindle",
                })
            end
        end
        for _, rule in ipairs(app_rules) do rule:set_enabled(false) end
        app_rules = {}
        local primary = names[state.primary] and state.primary or core.primary(monitors, fallback)
        for _, app in ipairs(apps) do
            app_rules[#app_rules + 1] = hl.window_rule({ match = { initial_class = app[1] }, workspace = tostring(state.bases[primary] + app[2]) })
        end
    end
    for _, window in ipairs(hl.get_windows()) do
        local data = meta(window)
        if data.restore_ws then data.restore_ws = core.destination(state.bases, monitors, data.restore_ws, fallback) end
        if data.home_ws then data.home_ws = core.destination(state.bases, monitors, data.home_ws, fallback) end
        if data.merged_into then data.merged_into = core.destination(state.bases, monitors, data.merged_into, fallback) end
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
    -- Waybar creates a bar for a hotplugged screen hidden (start_hidden), even
    -- while the bar is supposed to be shown. Re-send the desired state once the
    -- new bar exists; the signal is absolute, so repeating it is harmless.
    hl.on("monitor.added", function()
        later(function() hl.exec_cmd("bash ~/.config/hypr/scripts/waybar.sh resync") end, 400)
        later(function() hl.exec_cmd("bash ~/.config/hypr/scripts/waybar.sh resync") end, 2000)
    end)
    hl.on("monitor.removed", schedule_reconcile)
    hl.on("workspace.created", schedule_reconcile)
    hl.on("window.move_to_workspace", function(window, ws)
        if window then
            ws = ws or window.workspace
            local data = meta(window)
            -- Any move the merge code did not initiate ends the window's merge,
            -- unless it lands on a merged-away home and is adopted below.
            if not merging and data.merged_into then
                data.home_ws, data.merged_into = nil, nil
            end
            -- A window arriving on a merged-away home joins the merge instead,
            -- matching Awesome showing every client of a visible tag.
            if not merging and ws and not ws.special then
                local host = state.merges[ws.id]
                if host and workspace_visible(host) then
                    merging = true
                    hl.dispatch(hl.dsp.window.move({ window = window, workspace = host, follow = false }))
                    merging = false
                    data.home_ws, data.merged_into = ws.id, host
                    schedule_rebuild(host)
                    schedule_reconcile()
                    save()
                    return
                end
            end
            if not window.floating or mouse_window == window then schedule_rebuild(data.order_workspace) end
            if ws and not ws.special then
                if data.order_workspace ~= ws.id then
                    data.arrival_order = data.order or data.arrival_order
                    data.order = nil
                end
                data.order_workspace = ws.id
                if not window.floating or mouse_window == window then schedule_rebuild(ws.id) end
                -- The window's monitor may still be the source during this event.
                if data.sticky and ws.monitor then data.monitor = ws.monitor.name end
            end
            -- A window arriving on a visible workspace takes the pointer with
            -- it. Hidden destinations and special workspaces (minimized) are
            -- skipped: warping to an invisible rectangle yanks the pointer.
            if ws and not ws.special and workspace_visible(ws.id) then center_cursor_on(window) end
        end
        schedule_reconcile()
    end)
    hl.on("window.open", function(window)
        local ws = window.workspace
        if ws and ws.tiled_layout == "dwindle" and not window.floating then
            schedule_rebuild(ws.id)
        end
        reassert_top()
        save()
    end)
    hl.on("window.active", function(window, reason)
        -- Keyboard/binding focus changes take the cursor with them. Mouse
        -- focus changes (FFM, click) leave it where the user put it. The
        -- focus churn inside a rebuild must not drag the pointer along.
        if not rebuilding and reason and (reason & MOUSE_FOCUS_REASONS) == 0 then
            center_cursor_on(window)
        end
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
        if rebuild_deferred[ws.id] then
            rebuild_deferred[ws.id] = nil
            schedule_rebuild(ws.id)
        end
        for _, window in ipairs(hl.get_windows()) do
            local data = meta(window)
            if data.sticky and not data.minimized and ws.monitor and data.monitor == ws.monitor.name
                and window.workspace ~= ws then
                hl.dispatch(hl.dsp.window.move({ window = window, workspace = ws, follow = false }))
            end
        end
        -- Merges dissolve as soon as their host workspace is no longer shown.
        local dissolved = 0
        for home, host in pairs(state.merges) do
            if not workspace_visible(host) then
                state.merges[home] = nil
                dissolved = dissolved + 1
            end
        end
        dissolved = dissolved + unmerge(function(data) return not workspace_visible(data.merged_into) end)
        if dissolved > 0 then save() end
        sync_bar()
        publish_labels()
    end)
    hl.on("window.fullscreen", function() later(sync_bar) end)
    hl.on("window.close", function(window)
        local ws = window.workspace
        if ws and not window.floating then schedule_rebuild(ws.id) end
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
        M.place_apps()
        local live = {}
        for _, window in ipairs(hl.get_windows()) do live[key(window)] = true end
        for id in pairs(state.windows) do if not live[id] then state.windows[id] = nil end end
        for _, ws in ipairs(hl.get_workspaces()) do
            if not ws.special and ws.tiled_layout == "dwindle" then capture_order(ws) end
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
