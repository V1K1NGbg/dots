--[[

     Awesome WM configuration template
     github.com/lcpz

--]]

-- {{{ Required libraries

-- If LuaRocks is installed, make sure that packages installed through it are
-- found (e.g. lgi). If LuaRocks is not installed, do nothing.
pcall(require, "luarocks.loader")

local gears = require("gears")
local awful = require("awful")
require("awful.autofocus")
local wibox         = require("wibox")
local beautiful     = require("beautiful")
local naughty       = require("naughty")
local hotkeys_popup = require("awful.hotkeys_popup")
local mytable       = awful.util.table or gears.table -- 4.{0,1} compatibility

-- }}}

-- {{{ Error handling

-- Check if awesome encountered an error during startup and fell back to
-- another config (This code will only ever execute for the fallback config)
if awesome.startup_errors then
    naughty.notify {
        preset = naughty.config.presets.critical,
        title = "Oops, there were errors during startup!",
        text = awesome.startup_errors
    }
end

-- Handle runtime errors after startup
do
    local in_error = false

    awesome.connect_signal("debug::error", function(err)
        if in_error then return end

        in_error = true

        naughty.notify {
            preset = naughty.config.presets.critical,
            title = "Oops, an error happened!",
            text = tostring(err)
        }

        in_error = false
    end)
end

-- }}}

-- {{{ Autostart windowless processes

-- -- This function will run once every time Awesome is started
-- local function run_once(cmd_arr)
--     for _, cmd in ipairs(cmd_arr) do
--         awful.spawn.with_shell(string.format("pgrep -u $USER '%s' > /dev/null || (%s)", cmd, cmd))
--     end
-- end

-- run_once({ "nm-applet", "blueman-applet", "pcloud", "flameshot", "picom", "fusuma", "code", "alacritty", "discord", "nemo", "spotify-launcher", "firefox|MainThread"}) -- comma-separated entries
awful.spawn.with_shell(string.format("%s/.config/awesome/autostart.sh", os.getenv("HOME")))

-- {{{ Variable definitions

local modkey                = "Mod4"
local altkey                = "Mod1"

local terminal              = "alacritty"
local editor                = os.getenv("EDITOR") or "vim"
local guieditor             = "code"
local browser               = "firefox"
local files                 = "nemo"

local vi_focus              = false -- vi-like client focus https://github.com/lcpz/awesome-copycats/issues/275

awful.util.terminal         = terminal
awful.util.tagnames         = { "1", "2", "3", "4", "5", "6", "7", "8", "9" }
awful.layout.layouts        = {
    awful.layout.suit.spiral.dwindle,
    awful.layout.suit.tile,
    awful.layout.suit.fair,
    awful.layout.suit.floating,
}

awful.util.taglist_buttons  = mytable.join(
    awful.button({}, 1, function(t) t:view_only() end),
    awful.button({ modkey }, 1, function(t)
        if client.focus then client.focus:move_to_tag(t) end
    end),
    awful.button({}, 3, awful.tag.viewtoggle),
    awful.button({ modkey }, 3, function(t)
        if client.focus then client.focus:toggle_tag(t) end
    end),
    awful.button({}, 4, function(t) awful.tag.viewnext(t.screen) end),
    awful.button({}, 5, function(t) awful.tag.viewprev(t.screen) end)
)

awful.util.tasklist_buttons = mytable.join(
    awful.button({}, 1, function(c)
        if c == client.focus then
            c.minimized = true
        else
            c:emit_signal("request::activate", "tasklist", { raise = true })
        end
    end),
    awful.button({}, 3, function()
        awful.menu.client_list({ theme = { width = 250 } })
    end),
    awful.button({}, 4, function() awful.client.focus.byidx(1) end),
    awful.button({}, 5, function() awful.client.focus.byidx(-1) end)
)

beautiful.init(string.format("%s/.config/awesome/theme.lua", os.getenv("HOME")))

-- }}}

-- {{{ Menu

-- Create a launcher widget and a main menu
local myawesomemenu = {
    { "Hotkeys",     function() hotkeys_popup.show_help(nil, awful.screen.focused()) end },
    { "Manual",      string.format("%s -e man awesome", terminal) },
    { "Edit config", string.format("%s -e %s %s", terminal, editor, awesome.conffile) },
    { "Restart",     awesome.restart },
    { "Quit",        function() awesome.quit() end },
}

mymainmenu = awful.menu({
    items = { { "awesome", myawesomemenu, beautiful.awesome_icon },
        { "open terminal", terminal }
    }
})

-- Hide the menu when the mouse leaves it

mymainmenu.wibox:connect_signal("mouse::leave", function()
    if not mymainmenu.active_child or
        (mymainmenu.wibox ~= mouse.current_wibox and
            mymainmenu.active_child.wibox ~= mouse.current_wibox) then
        mymainmenu:hide()
    else
        mymainmenu.active_child.wibox:connect_signal("mouse::leave",
            function()
                if mymainmenu.wibox ~= mouse.current_wibox then
                    mymainmenu:hide()
                end
            end)
    end
end)

-- Magnify

function magnify_client(c, width_f, height_f)
    if c and not c.floating then
        magnified_client = c
        mc(c, width_f, height_f)
    else
        magnified_client = nil
        c.floating = false
    end
end

-- https://github.com/lcpz/lain/issues/195
function mc(c, width_f, height_f)
    c = c or magnified_client
    if not c then return end

    c.floating   = true
    local s      = awful.screen.focused()
    local mg     = s.workarea
    local g      = {}
    local mwfact = width_f or s.selected_tag.master_width_factor or 0.5
    g.width      = math.sqrt(mwfact) * mg.width
    g.height     = math.sqrt(height_f or mwfact) * mg.height
    g.x          = mg.x + (mg.width - g.width) / 2
    g.y          = mg.y + (mg.height - g.height) / 2

    if c then c:geometry(g) end -- if c is still a valid object
end

-- }}}

-- {{{ Screen

-- Re-set wallpaper when a screen's geometry changes (e.g. different resolution)
screen.connect_signal("property::geometry", function(s)
    -- Wallpaper
    if beautiful.wallpaper then
        local wallpaper = beautiful.wallpaper
        -- If wallpaper is a function, call it with the screen
        if type(wallpaper) == "function" then
            wallpaper = wallpaper(s)
        end
        gears.wallpaper.maximized(wallpaper, s, true)
    end
end)


-- Wallpaper
screen.connect_signal("request::wallpaper", function(s)
    awful.wallpaper {
        screen = s,
        widget = {
            {
                image     = beautiful.wallpaper,
                upscale   = true,
                downscale = true,
                widget    = wibox.widget.imagebox,
            },
            valign = "center",
            halign = "center",
            tiled  = false,
            widget = wibox.container.tile,
        }
    }
end)

-- Create a wibox for each screen and add it
awful.screen.connect_for_each_screen(function(s) beautiful.at_screen_connect(s) end)

-- }}}

-- {{{ Mouse bindings

root.buttons(mytable.join(
    awful.button({}, 3, function() mymainmenu:show() end),
    awful.button({}, 4, awful.tag.viewnext),
    awful.button({}, 5, awful.tag.viewprev)
))

-- }}}

-- {{{ Key bindings

globalkeys = mytable.join(

-- Restart
    awful.key({ modkey, "Shift" }, "r", awesome.restart,
        { description = "reload awesome", group = "awesome" }),

    -- Quit
    awful.key({ modkey, "Shift" }, "q", awesome.quit,
        { description = "quit awesome", group = "awesome" }),

    -- Show help
    awful.key({ modkey, }, "s", hotkeys_popup.show_help,
        { description = "show help", group = "awesome" }),

    -- Menu
    awful.key({ modkey, }, "w", function() mymainmenu:show() end,
        { description = "show main menu", group = "awesome" }),

    -- Default client focus
    awful.key({ modkey, "Shift" }, "Tab",
        function()
            awful.client.focus.byidx(-1)
        end,
        { description = "focus previous by index", group = "client" }
    ),
    awful.key({ modkey, }, "Tab",
        function()
            awful.client.focus.byidx(1)
        end,
        { description = "focus next by index", group = "client" }
    ),
    awful.key({ modkey }, "p", function() awful.spawn("flameshot gui") end,
        { description = "take a screenshot", group = "client" }),

    -- X screen locker
    awful.key({ modkey, }, "l", function() os.execute("~/i3lock.sh") end,
        { description = "lock screen", group = "client" }),

    -- Tag browsing
    awful.key({ modkey, }, ",", awful.tag.viewprev,
        { description = "view previous", group = "tag" }),
    awful.key({ modkey, }, ".", awful.tag.viewnext,
        { description = "view next", group = "tag" }),

    -- Layout manipulation
    awful.key({ modkey, "Shift" }, "j", function() awful.client.swap.byidx(1) end,
        { description = "swap with next client by index", group = "client" }),
    awful.key({ modkey, "Shift" }, "k", function() awful.client.swap.byidx(-1) end,
        { description = "swap with previous client by index", group = "client" }),
    awful.key({ modkey, }, "u", awful.client.urgent.jumpto,
        { description = "jump to urgent client", group = "client" }),
    -- awful.key({ modkey, }, "Tab",

    -- Standard program
    awful.key({ modkey, }, "Return", function() awful.spawn(terminal) end,
        { description = "open a terminal", group = "launcher" }),
    awful.key({ modkey, }, "b", function() awful.spawn(browser) end,
        { description = "open a browser", group = "launcher" }),
    awful.key({ modkey, }, "e", function() awful.spawn(files) end,
        { description = "open a file manager", group = "launcher" }),
    awful.key({ modkey, }, "c", function() awful.spawn(guieditor) end,
        { description = "open a vs code instance", group = "launcher" }),
    awful.key({ modkey, "Shift" }, "space", function() awful.layout.inc(1) end,
        { description = "select next", group = "client" }),

    awful.key({ modkey, "Shift" }, "n", function()
        local c = awful.client.restore()
        -- Focus restored client
        if c then
            c:emit_signal("request::activate", "key.unminimize", { raise = true })
        end
    end, { description = "restore minimized", group = "client" }),

    -- ALSA volume control
    awful.key({}, "XF86AudioRaiseVolume",
        function()
            os.execute(string.format("amixer -q set %s 5%%+", beautiful.volume.channel))
            beautiful.volume.update()
        end,
        { description = "volume up", group = "client" }),

    awful.key({}, "XF86AudioLowerVolume",
        function()
            os.execute(string.format("amixer -q set %s 5%%-", beautiful.volume.channel))
            beautiful.volume.update()
        end,
        { description = "volume down", group = "client" }),

    awful.key({}, "XF86AudioMute",
        function()
            os.execute(string.format("amixer -q set %s toggle",
                beautiful.volume.togglechannel or beautiful.volume.channel))
            beautiful.volume.update()
        end,
        { description = "toggle mute", group = "client" }),

    awful.key({ }, "XF86AudioPlay", function () awful.util.spawn("playerctl --player=spotify,%any play-pause") end),
    awful.key({ }, "XF86AudioNext", function () awful.util.spawn("playerctl --player=spotify,%any next") end),
    awful.key({ }, "XF86AudioPrev", function () awful.util.spawn("playerctl --player=spotify,%any previous") end),

    -- Prompt
    awful.key({ modkey }, "r", function() os.execute("rofi -terminal " .. terminal .. " -show run") end,
        { description = "run prompt, calc, apps, files...", group = "launcher" }),
    awful.key({ modkey, }, "semicolon", function() awful.screen.focus_relative(1) end,
        { description = "move to left screen", group = "client" }),
    awful.key({ modkey, }, "apostrophe", function() awful.screen.focus_relative(-1) end,
        { description = "move to right screen", group = "client" }),
    awful.key({ modkey, }, "g",
        function()
            awful.spawn.easy_async_with_shell("pgrep -x glava",
                function(stdout, stderr, reason, exit_code)
                    if exit_code == 0 then
                        awful.spawn.with_shell("pkill glava")
                    else
                        awful.spawn.with_shell("glava --desktop")
                    end
                end)
        end,
        { description = "start/stop glava", group = "client" }),
    awful.key({ altkey }, "h", function() os.execute("xdotool mousemove_relative -- -50 0") end,
        { description = "Move cursor", group = "client" }),
    awful.key({ altkey }, "j", function() os.execute("xdotool mousemove_relative -- 0 50") end,
        { description = "Move cursor", group = "client" }),
    awful.key({ altkey }, "k", function() os.execute("xdotool mousemove_relative -- 0 -50") end,
        { description = "Move cursor", group = "client" }),
    awful.key({ altkey }, "l", function() os.execute("xdotool mousemove_relative -- 50 0") end,
        { description = "Move cursor", group = "client" }),
    awful.key({ altkey, "Shift" }, "h", function() os.execute("xdotool mousemove_relative -- -5 0") end,
        { description = "Move cursor", group = "client" }),
    awful.key({ altkey, "Shift" }, "j", function() os.execute("xdotool mousemove_relative -- 0 5") end,
        { description = "Move cursor", group = "client" }),
    awful.key({ altkey, "Shift" }, "k", function() os.execute("xdotool mousemove_relative -- 0 -5") end,
        { description = "Move cursor", group = "client" }),
    awful.key({ altkey, "Shift" }, "l", function() os.execute("xdotool mousemove_relative -- 5 0") end,
        { description = "Move cursor", group = "client" }),
    awful.key({ altkey }, "[", function() os.execute("xdotool click 1") end,
        { description = "Left click cursor", group = "client" }),
    awful.key({ altkey }, "]", function() os.execute("xdotool click 3 ") end,
        { description = "Right click cursor", group = "client" })
)

clientkeys = mytable.join(
    -- Floating
    awful.key({ modkey, "Shift" }, "f",
        awful.client.floating.toggle,
        { description = "toggle floating", group = "client", }
    ),
    --Sticky
    awful.key({ modkey, "Shift" }, "s",
        function(c)
            c.sticky = not c.sticky
            c:raise()
        end,
        { description = "toggle sticky", group = "client" }),
    -- On top
    awful.key({ modkey, "Shift" }, "t",
        function(c)
            c.ontop = not c.ontop
            c:raise()
        end,
        { description = "toggle keep on top", group = "client" }),
    -- Magnify
    awful.key({ altkey, }, "m", magnify_client,
        { description = "magnify client", group = "client" }),
    awful.key({ modkey, }, "f",
        function(c)
            c.fullscreen = not c.fullscreen
            c:raise()
        end,
        { description = "toggle fullscreen", group = "client" }),
    awful.key({ modkey, }, "q", function(c) c:kill() end,
        { description = "close", group = "client" }),
    awful.key({ modkey, }, "n",
        function(c)
            -- The client currently has the input focus, so it cannot be
            -- minimized, since minimized clients can't have the focus.
            c.minimized = true
        end,
        { description = "minimize", group = "client" }),
    awful.key({ modkey, }, "m",
        function(c)
            c.maximized = not c.maximized
            c:raise()
        end,
        { description = "(un)maximize", group = "client" }),
    awful.key({ modkey, "Shift" }, "semicolon", function(c) c:move_to_screen(c.screen.index - 1) end,
        { description = "move client to left screen", group = "client" }),
    awful.key({ modkey, "Shift" }, "apostrophe", function(c) c:move_to_screen(c.screen.index + 1) end,
        { description = "move client to right screen", group = "client" })
)

-- Bind all key numbers to tags.
-- Be careful: we use keycodes to make it work on any keyboard layout.
-- This should map on the top row of your keyboard, usually 1 to 9.
for i = 1, 9 do
    globalkeys = mytable.join(globalkeys,
        -- View tag only.
        awful.key({ modkey }, "#" .. i + 9,
            function()
                local screen = awful.screen.focused()
                local tag = screen.tags[i]
                if tag then
                    tag:view_only()
                end
            end,
            { description = "view tag #" .. i, group = "tag" }),
        -- Toggle tag display.
        awful.key({ modkey, "Control" }, "#" .. i + 9,
            function()
                local screen = awful.screen.focused()
                local tag = screen.tags[i]
                if tag then
                    awful.tag.viewtoggle(tag)
                end
            end,
            { description = "toggle tag #" .. i, group = "tag" }),
        -- Move client to tag.
        awful.key({ modkey, "Shift" }, "#" .. i + 9,
            function()
                if client.focus then
                    local tag = client.focus.screen.tags[i]
                    if tag then
                        client.focus:move_to_tag(tag)
                    end
                end
            end,
            { description = "move focused client to tag #" .. i, group = "tag" })
    )
end

clientbuttons = mytable.join(
    awful.button({}, 1, function(c)
        c:emit_signal("request::activate", "mouse_click", { raise = true })
    end),
    awful.button({ modkey }, 1, function(c)
        c:emit_signal("request::activate", "mouse_click", { raise = true })
        awful.mouse.client.move(c)
    end),
    awful.button({ modkey }, 3, function(c)
        c:emit_signal("request::activate", "mouse_click", { raise = true })
        awful.mouse.client.resize(c)
    end)
)

-- Set keys
root.keys(globalkeys)

-- }}}

-- {{{ Rules

-- Rules to apply to new clients (through the "manage" signal).
awful.rules.rules = {
    
    -- Notification rules
    {
        rule = { type = "normal" },
        callback = function(c)
            -- Configure notifications appearance and behavior
            naughty.config.defaults.timeout = 5
            naughty.config.defaults.margin = 10
            naughty.config.defaults.position = "top_right"
            naughty.config.defaults.font = beautiful.font
            naughty.config.defaults.fg = beautiful.fg_normal
            naughty.config.defaults.bg = beautiful.bg_normal
            naughty.config.defaults.border_width = beautiful.border_width
            naughty.config.defaults.border_color = beautiful.border_focus
            
            -- Set minimum and maximum notification sizes
            naughty.config.defaults.max_width = 800
            naughty.config.defaults.max_height = 500

            -- Close notifications on click
            c:connect_signal("button::press", function()
                c:emit_signal("request::destroy")
            end)
            
        end,
        properties = {}
    },

    -- All clients will match this rule.
    {
        rule = {},
        properties = {
            border_width = beautiful.border_width,
            border_color = beautiful.border_normal,
            callback = awful.client.setslave,
            focus = awful.client.focus.filter,
            raise = true,
            --  titlebars_enabled = true, --maybe switch later
            keys = clientkeys,
            buttons = clientbuttons,
            screen = awful.screen.preferred,
            placement = awful.placement.no_overlap + awful.placement.no_offscreen,
            size_hints_honor = false,
        }
    },

    -- Floating clients.
    {
        rule_any = {
            instance = {
                "DTA",   -- Firefox addon DownThemAll.
                "copyq", -- Includes session name in class.
                "pinentry",
            },
            class = {
                "Arandr",
                "Blueman-manager",
                "Gpick",
                "Kruler",
                "MessageWin",  -- kalarm.
                "Sxiv",
                "Tor Browser", -- Needs a fixed window size to avoid fingerprinting by screen size.
                "Wpa_gui",
                "veromix",
                "xtightvncviewer" },

            -- Note that the name property shown in xprop might be set slightly after creation of the client
            -- and the name shown there might not match defined rules here.
            name = {
                "Event Tester", -- xev.
            },
            role = {
                "AlarmWindow",   -- Thunderbird's calendar.
                "ConfigManager", -- Thunderbird's about:config.
                "pop-up",        -- e.g. Google Chrome's (detached) Developer Tools.
            }
        },
        properties = { floating = true }
    },

    -- Add titlebars to normal clients and dialogs
    {
        rule_any = { type = { "normal", "dialog" }
        },
        properties = { titlebars_enabled = true }
    },

    -- Set VS Code to always map on the tag named "1" on screen 1.
    {
        rule = { class = "Code" },
        properties = { screen = 1, tag = "  " }
    },

    {
        rule = { class = "Firefox" },
        properties = { screen = 1, tag = "  " }
    },

    {
        rule = { class = "Alacritty" },
        properties = { screen = 1, tag = "  " }
    },

    {
        rule = { class = "discord" },
        properties = { screen = 1, tag = "  " }
    },

    {
        rule = { class = "Nemo" },
        properties = { screen = 1, tag = "  " }
    },

    {
        rule = { class = "Spotify" },
        properties = { screen = 1, tag = "  " }
    },

    {
        rule = { class = "KeePassXC" },
        properties = { screen = 1, tag = "  " }
    },

    {
        rule = { class = "steam" },
        properties = { screen = 1, tag = "  " }
    },
}

-- }}}

-- {{{ Signals

-- Signal function to execute when a new client appears.
client.connect_signal("manage", function(c)
    -- Set the windows at the slave,
    -- i.e. put it at the end of others instead of setting it master.
    -- if not awesome.startup then awful.client.setslave(c) end

    if awesome.startup
        and not c.size_hints.user_position
        and not c.size_hints.program_position then
        -- Prevent clients from being unreachable after screen count changes.
        awful.placement.no_offscreen(c)
    end
end)

-- Add a titlebar if titlebars_enabled is set to true in the rules.
client.connect_signal("request::titlebars", function(c)
    -- Custom
    if beautiful.titlebar_fun then
        beautiful.titlebar_fun(c)
        return
    end

    -- Default
    -- buttons for the titlebar
    local buttons = mytable.join(
        awful.button({}, 1, function()
            c:emit_signal("request::activate", "titlebar", { raise = true })
            awful.mouse.client.move(c)
        end),
        awful.button({}, 3, function()
            c:emit_signal("request::activate", "titlebar", { raise = true })
            awful.mouse.client.resize(c)
        end)
    )

    awful.titlebar(c, { size = 16 }):setup {
        { -- Left
            awful.titlebar.widget.iconwidget(c),
            buttons = buttons,
            layout  = wibox.layout.fixed.horizontal
        },
        {     -- Middle
            { -- Title
                align  = "center",
                widget = awful.titlebar.widget.titlewidget(c)
            },
            buttons = buttons,
            layout  = wibox.layout.flex.horizontal
        },
        { -- Right
            awful.titlebar.widget.floatingbutton(c),
            awful.titlebar.widget.maximizedbutton(c),
            awful.titlebar.widget.stickybutton(c),
            awful.titlebar.widget.ontopbutton(c),
            awful.titlebar.widget.closebutton(c),
            layout = wibox.layout.fixed.horizontal(),
            spacing = 10,
            color = beautiful.menu_fg_normal
        },
        layout = wibox.layout.align.horizontal
    }
end)

-- client.disconnect_signal("request::activate", awful.ewmh.activate)
-- function awful.ewmh.activate(c)
--     if c:isvisible() then
--         client.focus = c
--         c:raise()
--     end
-- end
-- client.connect_signal("request::activate", awful.ewmh.activate)

-- Enable jump to urgent client
client.connect_signal("property::urgent", function(c) c:jump_to() end)


-- Remove wibar on full screen
local function remove_wibar(c)
    if c.fullscreen or c.maximized then
        c.screen.mywibox.visible = false
    else
        c.screen.mywibox.visible = true
    end
end

-- Remove wibar on full screen
local function add_wibar(c)
    if c.fullscreen or c.maximized then
        c.screen.mywibox.visible = true
    end
end

client.connect_signal("property::fullscreen", remove_wibar)

client.connect_signal("request::unmanage", add_wibar)

-- Enable sloppy focus, so that focus follows mouse.
client.connect_signal("mouse::enter", function(c)
    c:emit_signal("request::activate", "mouse_enter", { raise = vi_focus })
end)

client.connect_signal("focus", function(c) c.border_color = beautiful.border_focus end)
client.connect_signal("unfocus", function(c) c.border_color = beautiful.border_normal end)

-- switch to parent after closing child window
local function backham()
    local s = awful.screen.focused()
    local c = awful.client.focus.history.get(s, 0)
    if c then
        client.focus = c
        c:raise()
    end
end

-- attach to minimized state
client.connect_signal("property::minimized", backham)
-- attach to closed state
client.connect_signal("unmanage", backham)
-- ensure there is always a selected client during tag switching or logins

gears.timer {
    timeout = 30,
    autostart = true,
    callback = function() collectgarbage() end
}
