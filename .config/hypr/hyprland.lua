-- Hyprland 0.56+ Lua configuration.
-- Colors and typography are taken from alacritty/alacritty.toml.

hl.monitor({
    output = "",
    mode = "preferred",
    position = "auto",
    -- Use native-size UI instead of Hyprland's larger automatic HiDPI scale.
    scale = 1,
})

hl.env("XCURSOR_THEME", "capitaine-cursors")
hl.env("XCURSOR_SIZE", "24")

hl.config({
    general = {
        gaps_in = 12,
        gaps_out = 18,
        border_size = 2,
        layout = "dwindle",
        -- Interactive move/resize is deliberately reserved for Super+mouse.
        resize_on_border = false,
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
            range = 10,
            render_power = 3,
            offset = { 0, 3 },
            color = "rgba(00000088)",
            color_inactive = "rgba(00000066)",
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
        workspace_swipe_distance = 550,
        workspace_swipe_min_speed_to_force = 0,
        workspace_swipe_cancel_ratio = 0.5,
        workspace_swipe_direction_lock_threshold = 10,
    },
    dwindle = {
        preserve_split = true,
        -- Every new split is placed to the right or below its parent, keeping
        -- the visual spiral anchored toward the bottom-right corner.
        force_split = 2,
        smart_split = false,
        use_active_for_splits = true,
    },
    master = {
        orientation = "left",
        mfact = 0.5,
        new_status = "slave",
    },
    scrolling = {
        column_width = 0.5,
    },
    binds = {
        drag_threshold = 6,
        pass_mouse_when_bound = false,
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
            -- One-finger click = left; two-finger click = right everywhere.
            clickfinger_behavior = true,
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

hl.curve("fluid", { type = "bezier", points = { { 0.25, 0.1 }, { 0.25, 1.0 } } })
hl.animation({ leaf = "windows", enabled = true, speed = 5.0, bezier = "fluid" })
hl.animation({ leaf = "fade", enabled = true, speed = 4.5, bezier = "fluid" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 5.5, bezier = "fluid", style = "slide" })

-- Session behavior lives separately so the visual configuration stays small.
dots = require("desktop")
dots.setup()

hl.on("hyprland.start", function()
    hl.exec_cmd("~/.config/hypr/autostart.sh")
end)

-- Utility surfaces should float; normal pCloud windows should tile.
hl.window_rule({ match = { initial_class = ".*[Pp][Cc]loud.*" }, float = false })
hl.window_rule({
    match = { initial_class = "(org\\.blueman\\.Manager|[Bb]lueman-manager|[Cc]opy[qQ]|[Pp]inentry.*|[Pp]avucontrol|[Gg]pick|[Kk]ruler|[Ss]xiv|[Ww]pa_gui|[Tt]or [Bb]rowser|[Aa]randr|[Xx]tightvncviewer)" },
    float = true,
})
hl.window_rule({ match = { title = "^(Open File|Save File|Save As|Authentication Required|Event Tester)$" }, float = true })

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

local cursor_reveal_generation = 0

local function move_cursor(x, y)
    return function()
        local position = hl.get_cursor_pos()
        if position then
            -- Programmatic cursor movement does not count as libinput motion.
            -- Debounce timeout restoration so held arrow keys do not flicker.
            cursor_reveal_generation = cursor_reveal_generation + 1
            local generation = cursor_reveal_generation
            hl.config({ cursor = { inactive_timeout = 0 } })
            hl.dispatch(hl.dsp.cursor.move({ x = position.x + x, y = position.y + y }))
            hl.timer(function()
                if generation == cursor_reveal_generation then
                    hl.config({ cursor = { inactive_timeout = 5 } })
                end
            end, { timeout = 800, type = "oneshot" })
        end
    end
end

-- Awesome/session controls.
bind(mod .. " + SHIFT + R", hl.dsp.exec_cmd("hyprctl reload && notify-send 'Hyprland configuration reloaded'"), "Reload Hyprland")
bind(mod .. " + SHIFT + Q", hl.dsp.exec_cmd("uwsm stop"), "Quit Hyprland")
bind(mod .. " + S", hl.dsp.exec_cmd("~/.config/rofi/keybinds.sh"), "Show keybinding help")

-- Client focus and workspace browsing.
bind(mod .. " + SHIFT + Tab", hl.dsp.window.cycle_next({ next = false }), "Focus previous window")
bind(mod .. " + Tab", hl.dsp.window.cycle_next({ next = true }), "Focus next window")
bind(mod .. " + comma", function() dots.browse(-1) end, "View previous workspace")
bind(mod .. " + period", function() dots.browse(1) end, "View next workspace")

-- Launchers and session utilities.
bind(mod .. " + Return", hl.dsp.exec_cmd("alacritty"), "Open a terminal")
bind(mod .. " + B", hl.dsp.exec_cmd("firefox"), "Open a browser")
bind(mod .. " + E", hl.dsp.exec_cmd("nemo"), "Open the file manager")
bind(mod .. " + C", hl.dsp.exec_cmd("code"), "Open VS Code")
bind(mod .. " + R", hl.dsp.exec_cmd("rofi -terminal alacritty -show run"), "Open the run prompt")
bind(mod .. " + P", hl.dsp.exec_cmd("grim -g \"$(slurp)\" - | swappy -f -"), "Take a screenshot")
bind(mod .. " + L", hl.dsp.exec_cmd("hyprlock"), "Lock the screen")
bind("XF86PowerOff", hl.dsp.exec_cmd("rofi -show power"), "Open the power menu")

-- Window and layout manipulation.
bind(mod .. " + J", function() dots.swap(1) end, "Swap with the next window")
bind(mod .. " + K", function() dots.swap(-1) end, "Swap with the previous window")
bind(mod .. " + SHIFT + J", function() dots.resize("+0.05") end, "Grow the current right/down split", { repeating = true })
bind(mod .. " + SHIFT + K", function() dots.resize("-0.05") end, "Shrink the current right/down split", { repeating = true })
bind(mod .. " + SHIFT + space", dots.cycle_layout, "Cycle Dwindle, Tile, Fair, and Floating layouts")
bind(mod .. " + SHIFT + F", hl.dsp.window.float({ action = "toggle" }), "Toggle floating")
bind(mod .. " + SHIFT + S", dots.toggle_sticky, "Toggle sticky")
bind(mod .. " + SHIFT + T", dots.toggle_ontop, "Toggle persistent keep on top")
bind(mod .. " + T", dots.toggle_bar, "Toggle the top bar")
bind(mod .. " + F", hl.dsp.window.fullscreen({ action = "toggle" }), "Toggle fullscreen")
bind(mod .. " + Q", hl.dsp.window.close(), "Close window")
bind(mod .. " + N", dots.minimize, "Minimize window")
bind(mod .. " + SHIFT + N", dots.restore, "Restore the last minimized window")
bind(mod .. " + M", hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" }), "Toggle maximized")

-- Monitor focus and client movement. Relative selectors follow Hyprland's
-- configured monitor order, matching Awesome's focus_relative behavior.
bind(mod .. " + semicolon", hl.dsp.focus({ monitor = "+1" }), "Focus the next monitor")
bind(mod .. " + apostrophe", hl.dsp.focus({ monitor = "-1" }), "Focus the previous monitor")
bind(mod .. " + SHIFT + semicolon", hl.dsp.window.move({ monitor = "-1" }), "Move window to the previous monitor")
bind(mod .. " + SHIFT + apostrophe", hl.dsp.window.move({ monitor = "+1" }), "Move window to the next monitor")

-- Keyboard-driven pointer control.
bind(mod .. " + left", move_cursor(-16, 0), "Move pointer left", { repeating = true })
bind(mod .. " + down", move_cursor(0, 16), "Move pointer down", { repeating = true })
bind(mod .. " + up", move_cursor(0, -16), "Move pointer up", { repeating = true })
bind(mod .. " + right", move_cursor(16, 0), "Move pointer right", { repeating = true })
bind(mod .. " + SHIFT + left", move_cursor(-3, 0), "Nudge pointer left", { repeating = true })
bind(mod .. " + SHIFT + down", move_cursor(0, 3), "Nudge pointer down", { repeating = true })
bind(mod .. " + SHIFT + up", move_cursor(0, -3), "Nudge pointer up", { repeating = true })
bind(mod .. " + SHIFT + right", move_cursor(3, 0), "Nudge pointer right", { repeating = true })
bind(mod .. " + bracketleft", click("mouse:272"), "Left-click the pointer")
bind(mod .. " + bracketright", click("mouse:273"), "Right-click the pointer")

for i = 1, 9 do
    bind(mod .. " + " .. i, function() dots.view(i) end, "View workspace " .. i)
    bind(mod .. " + SHIFT + " .. i, function() dots.move(i) end, "Move window to workspace " .. i)
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
