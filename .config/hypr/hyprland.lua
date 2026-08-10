-- Minimal Hyprland 0.55+ profile inspired by the Awesome configuration.

local home = os.getenv("HOME")
local mod = "SUPER"
local scripts = home .. "/.config/hypr/scripts/"

local colors = {
    gray = "404040",
    white = "f8f8f2",
}

-- Display layout: preserve the two known laptop generations and external panel.
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })

local function find_monitor(name, description)
    for _, monitor in ipairs(hl.get_monitors()) do
        if monitor.name == name
            or (monitor.description and string.find(monitor.description, description, 1, true)) then
            return monitor.name
        end
    end
end

local function configure_monitors()
    local external = find_monitor("DP-3", "MSI MAG272QR")
        or find_monitor("DisplayPort-3", "MSI MAG272QR")
    local current_panel = find_monitor("eDP", "NE160QDM-NZ6")
    local old_panel = find_monitor("eDP-1", "HMH2Y")

    if external and current_panel then
        hl.monitor({ output = external, mode = "2560x1440@60", position = "0x0", scale = 1 })
        hl.monitor({ output = current_panel, mode = "1920x1200@165", position = "2560x240", scale = 1 })
    elseif external and old_panel then
        hl.monitor({ output = external, mode = "2560x1440@59.95", position = "0x0", scale = 1 })
        hl.monitor({ output = old_panel, mode = "1920x1080@59.96", position = "2560x360", scale = 1 })
    elseif current_panel then
        hl.monitor({ output = current_panel, mode = "2560x1600@165", position = "0x0", scale = 1 })
    elseif old_panel then
        hl.monitor({ output = old_panel, mode = "2560x1440@240", position = "0x0", scale = 1 })
    end
end

hl.config({
    general = {
        gaps_in = 6,
        gaps_out = 6,
        border_size = 2,
        layout = "dwindle",
        resize_on_border = true,
        allow_tearing = false,
        col = {
            active_border = "rgba(" .. colors.white .. "ff)",
            inactive_border = "rgba(" .. colors.gray .. "ff)",
        },
    },
    decoration = {
        rounding = 0,
        active_opacity = 1,
        inactive_opacity = 1,
        shadow = { enabled = false },
        blur = { enabled = false },
    },
    animations = { enabled = true },
    input = {
        kb_layout = "us,bg",
        kb_variant = ",bas_phonetic",
        kb_options = "grp:win_space_toggle",
        repeat_rate = 40,
        repeat_delay = 220,
        follow_mouse = 1,
        touchpad = {
            natural_scroll = true,
            tap_to_click = true,
            clickfinger_behavior = true,
        },
    },
    dwindle = {
        preserve_split = true,
        smart_resizing = true,
        use_active_for_splits = true,
    },
    misc = {
        disable_hyprland_logo = true,
        disable_splash_rendering = true,
        middle_click_paste = false,
        focus_on_activate = true,
    },
})

-- Keep the Awesome geometry, but use current Hyprland-native motion.
hl.curve("quick", { type = "bezier", points = { { 0.15, 0 }, { 0.1, 1 } } })
hl.curve("linear", { type = "bezier", points = { { 0, 0 }, { 1, 1 } } })
hl.curve("soft", { type = "bezier", points = { { 0.5, 0.5 }, { 0.75, 1 } } })
hl.curve("spring", { type = "spring", mass = 1, stiffness = 238.1191, dampening = 24.2128 })
hl.animation({ leaf = "global", enabled = true, speed = 8, bezier = "quick" })
hl.animation({ leaf = "windows", enabled = true, speed = 4.8, spring = "spring" })
hl.animation({ leaf = "windowsIn", enabled = true, speed = 4.1, spring = "spring", style = "popin 94%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 1.5, bezier = "linear", style = "popin 94%" })
hl.animation({ leaf = "fade", enabled = true, speed = 3, bezier = "quick" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 3.5, bezier = "soft", style = "slide" })

-- Session services. The start event fires once, rather than on every config reload.
hl.on("hyprland.start", function()
    configure_monitors()
    for _, command in ipairs({
        "hyprpaper",
        "hypridle",
        "hyprsunset",
        "mako",
        "systemctl --user start hyprpolkitagent.service",
        "pcloud",
    }) do
        hl.exec_cmd(command)
    end
end)
hl.on("monitor.added", configure_monitors)
hl.on("monitor.removed", configure_monitors)

-- Workspaces and application routing mirror Awesome's tags.
for workspace = 1, 9 do
    hl.workspace_rule({ workspace = tostring(workspace), persistent = true })
end

for _, app in ipairs({
    { "[Cc]ode", "1" },
    { "[Ff]irefox", "2" },
    { "[Aa]lacritty", "3" },
    { "[Nn]emo", "4" },
    { "[Dd]iscord", "5" },
    { "[Ss]potify", "6" },
    { "KeePassXC", "7" },
    { "[Ss]team", "8" },
}) do
    hl.window_rule({ match = { class = app[1] }, workspace = app[2] })
end

for _, class in ipairs({
    "Arandr", "Blueman-manager", "Gpick", "pinentry.*", "org.pulseaudio.pavucontrol",
    "nm-connection-editor", "org.gnome.FileRoller", "satty",
}) do
    hl.window_rule({
        match = { class = class },
        float = true,
        center = true,
        persistent_size = true,
    })
end

hl.window_rule({ match = { modal = true }, float = true, center = true })
hl.window_rule({ match = { xwayland = true, class = "^$", title = "^$" }, no_focus = true })
hl.window_rule({ match = { class = ".*" }, idle_inhibit = "fullscreen" })

local function bind(keys, dispatcher, options)
    hl.bind(keys, dispatcher, options or {})
end

-- Launchers and session controls.
bind(mod .. " + RETURN", hl.dsp.exec_cmd("alacritty"))
bind(mod .. " + B", hl.dsp.exec_cmd("firefox"))
bind(mod .. " + E", hl.dsp.exec_cmd("nemo"))
bind(mod .. " + C", hl.dsp.exec_cmd("code"))
bind(mod .. " + R", hl.dsp.exec_cmd("rofi -terminal alacritty -show run"))
bind(mod .. " + W", hl.dsp.exec_cmd("rofi -terminal alacritty -show run"))
bind(mod .. " + S", hl.dsp.exec_cmd(scripts .. "keybinds"))
bind(mod .. " + L", hl.dsp.exec_cmd("hyprlock"))
bind(mod .. " + P", hl.dsp.exec_cmd(scripts .. "screenshot"))
bind(mod .. " + SHIFT + R", hl.dsp.exec_cmd("hyprctl reload"))
bind(mod .. " + SHIFT + Q", hl.dsp.exec_cmd("uwsm stop"))

-- Window controls.
bind(mod .. " + Q", hl.dsp.window.close())
bind(mod .. " + F", hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" }))
bind(mod .. " + M", hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" }))
bind(mod .. " + SHIFT + F", hl.dsp.window.float({ action = "toggle" }))
bind(mod .. " + SHIFT + S", hl.dsp.window.pin({ action = "toggle" }))
bind(mod .. " + SHIFT + T", hl.dsp.window.alter_zorder({ mode = "top" }))
bind(mod .. " + TAB", hl.dsp.window.cycle_next({ next = true }))
bind(mod .. " + SHIFT + TAB", hl.dsp.window.cycle_next({ next = false }))
bind(mod .. " + U", hl.dsp.focus({ urgent_or_last = true }))

for _, item in ipairs({
    { key = "H", direction = "l", x = -40, y = 0 },
    { key = "L", direction = "r", x = 40, y = 0 },
    { key = "K", direction = "u", x = 0, y = -40 },
    { key = "J", direction = "d", x = 0, y = 40 },
}) do
    bind(mod .. " + " .. item.key, hl.dsp.focus({ direction = item.direction }))
    bind(mod .. " + SHIFT + " .. item.key, hl.dsp.window.swap({ direction = item.direction }))
    bind(mod .. " + CTRL + " .. item.key,
        hl.dsp.window.resize({ x = item.x, y = item.y, relative = true }), { repeating = true })
end

-- Tags, monitors, minimize emulation, and scratchpad.
bind(mod .. " + comma", hl.dsp.focus({ workspace = "r-1" }))
bind(mod .. " + period", hl.dsp.focus({ workspace = "r+1" }))
bind(mod .. " + semicolon", hl.dsp.focus({ monitor = "+1" }))
bind(mod .. " + apostrophe", hl.dsp.focus({ monitor = "-1" }))
bind(mod .. " + SHIFT + semicolon", hl.dsp.window.move({ monitor = "+1", follow = true }))
bind(mod .. " + SHIFT + apostrophe", hl.dsp.window.move({ monitor = "-1", follow = true }))

for workspace = 1, 9 do
    bind(mod .. " + " .. workspace, hl.dsp.focus({ workspace = workspace }))
    bind(mod .. " + SHIFT + " .. workspace,
        hl.dsp.window.move({ workspace = workspace, follow = false }))
end

bind(mod .. " + N", function()
    local window = hl.get_active_window()
    if not window then return end
    hl.dispatch(hl.dsp.window.tag({ tag = "minimized", window = window }))
    hl.dispatch(hl.dsp.window.move({ workspace = "special:minimized", follow = false, window = window }))
end)
bind(mod .. " + SHIFT + N", function()
    local workspace = hl.get_active_workspace()
    if not workspace then return end
    hl.dispatch(hl.dsp.window.move({ workspace = workspace, window = "tag:minimized" }))
    hl.dispatch(hl.dsp.window.clear_tags({ window = "tag:minimized" }))
end)
bind(mod .. " + grave", hl.dsp.workspace.toggle_special("scratch"))
bind(mod .. " + SHIFT + grave", hl.dsp.window.move({ workspace = "special:scratch", follow = false }))

-- Cycle the current workspace through the four native Awesome analogues.
bind(mod .. " + SHIFT + SPACE", function()
    local layouts = { "dwindle", "master", "scrolling", "monocle" }
    local workspace = hl.get_active_special_workspace() or hl.get_active_workspace()
    if not workspace then return end

    local next_layout = layouts[1]
    for index, layout in ipairs(layouts) do
        if layout == workspace.tiled_layout then
            next_layout = layouts[index % #layouts + 1]
            break
        end
    end

    local selector = workspace.special and tostring(workspace.name) or tostring(workspace.id)
    hl.workspace_rule({ workspace = selector, layout = next_layout })
end)

-- Pointer and mouse controls.
local function move_cursor(x, y)
    return function()
        local position = hl.get_cursor_pos()
        hl.dispatch(hl.dsp.cursor.move({ x = position.x + x, y = position.y + y }))
    end
end

for _, item in ipairs({
    { key = "left", x = -50, y = 0 },
    { key = "right", x = 50, y = 0 },
    { key = "up", x = 0, y = -50 },
    { key = "down", x = 0, y = 50 },
}) do
    bind(mod .. " + " .. item.key, move_cursor(item.x, item.y), { repeating = true })
    bind(mod .. " + SHIFT + " .. item.key,
        move_cursor(item.x / 10, item.y / 10), { repeating = true })
end

bind(mod .. " + bracketleft", hl.dsp.exec_cmd("wlrctl pointer click left"))
bind(mod .. " + bracketright", hl.dsp.exec_cmd("wlrctl pointer click right"))
bind(mod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
bind(mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })
bind(mod .. " + mouse_up", hl.dsp.focus({ workspace = "r+1" }))
bind(mod .. " + mouse_down", hl.dsp.focus({ workspace = "r-1" }))

-- Audio and media keys remain available while locked.
bind("XF86AudioRaiseVolume",
    hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"),
    { locked = true, repeating = true })
bind("XF86AudioLowerVolume",
    hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),
    { locked = true, repeating = true })
bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { locked = true })
bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl --player=spotify,%any play-pause"), { locked = true })
bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl --player=spotify,%any play-pause"), { locked = true })
bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl --player=spotify,%any next"), { locked = true })
bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl --player=spotify,%any previous"), { locked = true })

hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })
