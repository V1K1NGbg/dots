-- Hyprland 0.56+ Lua configuration.
-- Colors and typography are taken from alacritty/alacritty.toml.

hl.monitor({
    output = "",
    mode = "preferred",
    position = "auto",
    -- Use native-size UI instead of Hyprland's larger automatic HiDPI scale.
    scale = 1,
})

hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")

hl.config({
    general = {
        gaps_in = 6,
        gaps_out = 3,
        border_size = 2,
        layout = "dwindle",
        resize_on_border = true,
        allow_tearing = false,
        col = {
            active_border = "rgb(67ffeb)",
            inactive_border = "rgb(404040)",
        },
    },
    decoration = {
        rounding = 6,
        active_opacity = 1.0,
        inactive_opacity = 0.96,
        shadow = {
            enabled = true,
            range = 8,
            render_power = 3,
            color = "rgba(00000099)",
        },
        blur = {
            enabled = true,
            size = 4,
            passes = 2,
        },
    },
    animations = {
        enabled = true,
    },
    gestures = {
        workspace_swipe_distance = 400,
        workspace_swipe_min_speed_to_force = 0,
        workspace_swipe_cancel_ratio = 0.35,
        workspace_swipe_direction_lock_threshold = 20,
    },
    dwindle = {
        preserve_split = true,
    },
    input = {
        kb_layout = "us,bg",
        kb_variant = ",bas_phonetic",
        kb_options = "grp:win_space_toggle",
        repeat_delay = 220,
        repeat_rate = 40,
        follow_mouse = 1,
        touchpad = {
            tap_to_click = true,
            natural_scroll = true,
            disable_while_typing = true,
        },
    },
    cursor = {
        inactive_timeout = 5,
    },
    misc = {
        disable_hyprland_logo = true,
        disable_splash_rendering = true,
        session_lock_xray = true,
        background_color = "rgb(191919)",
        font_family = "Monocraft Nerd Font",
        focus_on_activate = true,
    },
    ecosystem = {
        no_update_news = true,
        no_donation_nag = true,
    }
})

hl.curve("fluid", { type = "bezier", points = { { 0.4, 0.0 }, { 0.2, 1.0 } } })
hl.animation({ leaf = "windows", enabled = true, speed = 3.5, bezier = "fluid" })
hl.animation({ leaf = "fade", enabled = true, speed = 3.5, bezier = "fluid" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 3.2, bezier = "fluid", style = "slide" })

hl.gesture({
    fingers = 3,
    direction = "horizontal",
    action = "workspace",
})

hl.on("hyprland.start", function()
    hl.exec_cmd("~/.config/hypr/autostart.sh")
end)

-- Keep the main applications on predictable workspaces. Match the initial
-- class so later title/class changes cannot move an already-open window.
local workspace_apps = {
    { class = "[Cc]ode", workspace = "1" },
    { class = "[Ff]irefox", workspace = "2" },
    { class = "[Aa]lacritty", workspace = "3" },
    { class = "[Nn]emo", workspace = "4" },
    { class = "[Dd]iscord", workspace = "5" },
    { class = "[Ss]potify", workspace = "6" },
    { class = "(org\\.keepassxc\\.KeePassXC|[Kk]ee[Pp]ass[Xx][Cc])", workspace = "7" },
}

for _, app in ipairs(workspace_apps) do
    hl.window_rule({
        match = { initial_class = app.class },
        workspace = app.workspace,
    })
end

local mod = "SUPER"

local function bind(keys, dispatcher, description, options)
    options = options or {}
    options.description = description
    hl.bind(keys, dispatcher, options)
end

local function click(button)
    return function()
        hl.dispatch(hl.dsp.send_key_state({ mods = "", key = button, state = "down" }))
        hl.dispatch(hl.dsp.send_key_state({ mods = "", key = button, state = "up" }))
    end
end

local function move_cursor(x, y)
    return function()
        local position = hl.get_cursor_pos()
        if position then
            hl.dispatch(hl.dsp.cursor.move({ x = position.x + x, y = position.y + y }))
        end
    end
end

local minimized_windows = {}

local function minimize_window()
    local window = hl.get_active_window()
    local workspace = window and window.workspace
    if not window or not workspace or workspace.special then
        return
    end

    table.insert(minimized_windows, { window = window, workspace = workspace.id })
    hl.dispatch(hl.dsp.window.move({
        window = window,
        workspace = "special:minimized",
        follow = false,
    }))
end

local function restore_minimized_window()
    local entry = table.remove(minimized_windows)
    if not entry then
        -- The in-memory stack is cleared by a config reload. Fall back to a
        -- window still parked on the minimized special workspace.
        local minimized_workspace = hl.get_workspace("special:minimized")
        local active_workspace = hl.get_active_workspace()
        local windows = minimized_workspace and hl.get_windows({ workspace = minimized_workspace }) or {}
        local window = windows[#windows]
        if not window or not active_workspace or active_workspace.special then
            return
        end
        entry = { window = window, workspace = active_workspace.id }
    end

    hl.dispatch(hl.dsp.window.move({
        window = entry.window,
        workspace = entry.workspace,
        follow = true,
    }))
end

hl.on("window.close", function(window)
    for i = #minimized_windows, 1, -1 do
        if minimized_windows[i].window == window then
            table.remove(minimized_windows, i)
        end
    end
end)

-- Awesome/session controls.
bind(mod .. " + SHIFT + R", hl.dsp.exec_cmd("hyprctl reload"), "Reload Hyprland")
bind(mod .. " + SHIFT + Q", hl.dsp.exec_cmd("uwsm stop"), "Quit Hyprland")
bind(mod .. " + S", hl.dsp.exec_cmd("~/.config/rofi/keybinds.sh"), "Show keybinding help")
bind(mod .. " + W", hl.dsp.exec_cmd("rofi -show drun"), "Show main menu")

-- Client focus and workspace browsing.
bind(mod .. " + SHIFT + Tab", hl.dsp.window.cycle_next({ next = false }), "Focus previous window")
bind(mod .. " + Tab", hl.dsp.window.cycle_next({ next = true }), "Focus next window")
bind(mod .. " + comma", hl.dsp.focus({ workspace = "e-1" }), "View previous workspace")
bind(mod .. " + period", hl.dsp.focus({ workspace = "e+1" }), "View next workspace")
bind(mod .. " + U", hl.dsp.focus({ urgent_or_last = true }), "Jump to urgent window")

-- Launchers and session utilities.
bind(mod .. " + Return", hl.dsp.exec_cmd("alacritty"), "Open a terminal")
bind(mod .. " + B", hl.dsp.exec_cmd("firefox"), "Open a browser")
bind(mod .. " + E", hl.dsp.exec_cmd("nemo"), "Open the file manager")
bind(mod .. " + C", hl.dsp.exec_cmd("code"), "Open VS Code")
bind(mod .. " + R", hl.dsp.exec_cmd("rofi -terminal alacritty -show run"), "Open the run prompt")
bind(mod .. " + P", hl.dsp.exec_cmd("grim -g \"$(slurp)\" - | swappy -f -"), "Take a screenshot")
bind(mod .. " + L", hl.dsp.exec_cmd("hyprlock"), "Lock the screen")
bind(mod .. " + SHIFT + E", hl.dsp.exec_cmd("rofi -show power"), "Open the power menu")
bind("XF86PowerOff", hl.dsp.exec_cmd("rofi -show power"), "Open the power menu")

-- Window and layout manipulation.
bind(mod .. " + SHIFT + J", hl.dsp.window.swap({ next = true }), "Swap with the next window")
bind(mod .. " + SHIFT + K", hl.dsp.window.swap({ prev = true }), "Swap with the previous window")
bind(mod .. " + SHIFT + space", hl.dsp.layout("togglesplit"), "Toggle split orientation")
bind(mod .. " + SHIFT + F", hl.dsp.window.float({ action = "toggle" }), "Toggle floating")
bind(mod .. " + SHIFT + S", hl.dsp.window.pin({ action = "toggle" }), "Toggle sticky")
bind(mod .. " + SHIFT + T", hl.dsp.window.alter_zorder({ mode = "top" }), "Raise above other windows")
bind(mod .. " + T", hl.dsp.exec_cmd("pkill -SIGUSR1 waybar"), "Toggle the top bar")
bind(mod .. " + SHIFT + M", hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" }), "Magnify window")
bind(mod .. " + F", hl.dsp.window.fullscreen({ action = "toggle" }), "Toggle fullscreen")
bind(mod .. " + Q", hl.dsp.window.close(), "Close window")
bind(mod .. " + N", minimize_window, "Minimize window")
bind(mod .. " + SHIFT + N", restore_minimized_window, "Restore the last minimized window")
bind(mod .. " + M", hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" }), "Toggle maximized")

-- Monitor focus and client movement. Relative selectors follow Hyprland's
-- configured monitor order, matching Awesome's focus_relative behavior.
bind(mod .. " + semicolon", hl.dsp.focus({ monitor = "+1" }), "Focus the next monitor")
bind(mod .. " + apostrophe", hl.dsp.focus({ monitor = "-1" }), "Focus the previous monitor")
bind(mod .. " + SHIFT + semicolon", hl.dsp.window.move({ monitor = "-1" }), "Move window to the previous monitor")
bind(mod .. " + SHIFT + apostrophe", hl.dsp.window.move({ monitor = "+1" }), "Move window to the next monitor")

bind(mod .. " + G", hl.dsp.exec_cmd("pkill -x glava || glava --desktop"), "Start or stop GLava")

-- Keyboard-driven pointer control.
bind(mod .. " + left", move_cursor(-50, 0), "Move pointer left", { repeating = true })
bind(mod .. " + down", move_cursor(0, 50), "Move pointer down", { repeating = true })
bind(mod .. " + up", move_cursor(0, -50), "Move pointer up", { repeating = true })
bind(mod .. " + right", move_cursor(50, 0), "Move pointer right", { repeating = true })
bind(mod .. " + SHIFT + left", move_cursor(-5, 0), "Nudge pointer left", { repeating = true })
bind(mod .. " + SHIFT + down", move_cursor(0, 5), "Nudge pointer down", { repeating = true })
bind(mod .. " + SHIFT + up", move_cursor(0, -5), "Nudge pointer up", { repeating = true })
bind(mod .. " + SHIFT + right", move_cursor(5, 0), "Nudge pointer right", { repeating = true })
bind(mod .. " + bracketleft", click("mouse:272"), "Left-click the pointer")
bind(mod .. " + bracketright", click("mouse:273"), "Right-click the pointer")

-- Workspaces replace Awesome tags. Hyprland cannot display multiple normal
-- workspaces at once, so Control+number focuses the requested workspace too.
for i = 1, 9 do
    bind(mod .. " + " .. i, hl.dsp.focus({ workspace = i }), "View workspace " .. i)
    bind(mod .. " + CTRL + " .. i, hl.dsp.focus({ workspace = i }), "View workspace " .. i)
    bind(mod .. " + SHIFT + " .. i, hl.dsp.window.move({ workspace = i }), "Move window to workspace " .. i)
end

bind(mod .. " + mouse:272", hl.dsp.window.drag(), "Move window with the mouse", { mouse = true })
bind(mod .. " + mouse:273", hl.dsp.window.resize(), "Resize window with the mouse", { mouse = true })

-- PipeWire volume and MPRIS media controls.
bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%+"), "Raise volume", { locked = true, repeating = true })
bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), "Lower volume", { locked = true, repeating = true })
bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), "Toggle audio mute", { locked = true })
bind("XF86AudioMicMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), "Toggle microphone mute", { locked = true })
bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl --player=spotify,%any play-pause"), "Play or pause media", { locked = true })
bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl --player=spotify,%any next"), "Play the next track", { locked = true })
bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl --player=spotify,%any previous"), "Play the previous track", { locked = true })
bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl set 5%+"), "Raise display brightness", { locked = true, repeating = true })
bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl set 5%-"), "Lower display brightness", { locked = true, repeating = true })
bind("Print", hl.dsp.exec_cmd("grim -g \"$(slurp)\" - | swappy -f -"), "Take a screenshot")
