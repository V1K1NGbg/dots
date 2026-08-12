-- Minimal Hyprland 0.55+ configuration.

local mod = "SUPER"

hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })

hl.config({
    general = {
        layout = "dwindle",
        gaps_in = 5,
        gaps_out = 10,
        border_size = 2,
        col = {
            active_border = "rgba(89b4faff)",
            inactive_border = "rgba(45475aff)",
        },
    },
    decoration = {
        rounding = 8,
        shadow = { enabled = false },
        blur = { enabled = false },
    },
    animations = { enabled = true },
    input = {
        kb_layout = "us",
        follow_mouse = 1,
        touchpad = { natural_scroll = true },
    },
    dwindle = {
        preserve_split = true,
    },
    misc = {
        disable_hyprland_logo = true,
        disable_splash_rendering = true,
    },
})

hl.curve("smooth", { type = "bezier", points = { { 0.25, 0.1 }, { 0.25, 1 } } })
hl.animation({ leaf = "windows", enabled = true, speed = 5, bezier = "smooth", style = "popin 90%" })
hl.animation({ leaf = "fade", enabled = true, speed = 5, bezier = "smooth" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 5, bezier = "smooth", style = "slide" })

hl.on("hyprland.start", function()
    hl.exec_cmd("swaybg --color '#1e1e2e'")
end)

local function bind(keys, dispatcher, options)
    hl.bind(keys, dispatcher, options or {})
end

bind(mod .. " + RETURN", hl.dsp.exec_cmd("alacritty"))
bind(mod .. " + R", hl.dsp.exec_cmd("rofi -show drun"))
bind(mod .. " + Q", hl.dsp.window.close())
bind(mod .. " + SHIFT + Q", hl.dsp.exec_cmd("uwsm stop"))
bind(mod .. " + F", hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" }))

for _, item in ipairs({
    { key = "H", direction = "l" },
    { key = "J", direction = "d" },
    { key = "K", direction = "u" },
    { key = "L", direction = "r" },
}) do
    bind(mod .. " + " .. item.key, hl.dsp.focus({ direction = item.direction }))
    bind(mod .. " + SHIFT + " .. item.key, hl.dsp.window.swap({ direction = item.direction }))
end

for workspace = 1, 9 do
    bind(mod .. " + " .. workspace, hl.dsp.focus({ workspace = workspace }))
    bind(mod .. " + SHIFT + " .. workspace, hl.dsp.window.move({
        workspace = workspace,
        follow = false,
    }))
end

bind(mod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
bind(mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })
