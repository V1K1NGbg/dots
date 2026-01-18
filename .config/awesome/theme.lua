--[[

     Multicolor Awesome WM theme 2.0
     github.com/lcpz

--]]

local gears    = require("gears")
local lain     = require("lain")
local awful    = require("awful")
local wibox    = require("wibox")
local dpi      = require("beautiful.xresources").apply_dpi
local const    = require("const")

local os       = os
local my_table = awful.util.table or gears.table -- 4.{0,1} compatibility

blackblack     = "#000000"
black          = "#191919"
gray           = "#404040"
white          = "#f8f8f2"
red            = "#ff025f"
green          = "#a2f300"
orange         = "#ffb247"
blue           = "#35ddff"
purple         = "#9359ff"
cyan           = "#67ffeb"

font           = "Monocraft Nerd Font 12"
fontbig        = "Monocraft Nerd Font 13"


local theme                                     = {}
theme.bg_systray                                = black

theme.confdir                                   = os.getenv("HOME") .. "/.config/awesome/"

theme.wallpaper                                 = theme.confdir .. "/wall.jpg"

theme.font                                      = font
theme.hotkeys_font                              = fontbig
theme.hotkeys_description_font                  = font

theme.menu_bg_normal                            = black
theme.menu_bg_focus                             = black
theme.bg_normal                                 = blackblack
theme.bg_focus                                  = black
theme.bg_urgent                                 = black

theme.fg_normal                                 = white
-- theme.fg_focus                                  = white
-- theme.fg_urgent                                 = red
theme.fg_minimize                               = gray
theme.border_width                              = dpi(1)
theme.border_normal                             = black
theme.border_focus                              = gray
theme.border_marked                             = blue
theme.menu_border_width                         = 0
theme.menu_width                                = dpi(130)

theme.menu_submenu_icon                         = theme.confdir .. "/icons/submenu.png"

theme.menu_fg_normal                            = white
theme.menu_fg_focus                             = cyan

theme.widget_temp                               = theme.confdir .. "/icons/temp.png"
theme.widget_uptime                             = theme.confdir .. "/icons/ac.png"
theme.widget_cpu                                = theme.confdir .. "/icons/cpu.png"
theme.widget_weather                            = theme.confdir .. "/icons/dish.png"
theme.widget_fs                                 = theme.confdir .. "/icons/fs.png"
theme.widget_mem                                = theme.confdir .. "/icons/mem.png"
theme.widget_note                               = theme.confdir .. "/icons/note.png"
theme.widget_note_on                            = theme.confdir .. "/icons/note_on.png"
theme.widget_netdown                            = theme.confdir .. "/icons/net_down.png"
theme.widget_netup                              = theme.confdir .. "/icons/net_up.png"
theme.widget_mail                               = theme.confdir .. "/icons/mail.png"
theme.widget_batt                               = theme.confdir .. "/icons/bat.png"
theme.widget_clock                              = theme.confdir .. "/icons/clock.png"
theme.widget_vol                                = theme.confdir .. "/icons/spkr.png"
theme.layout_tile                               = theme.confdir .. "/icons/tile.png"
theme.layout_tilegaps                           = theme.confdir .. "/icons/tilegaps.png"
theme.layout_tileleft                           = theme.confdir .. "/icons/tileleft.png"
theme.layout_tilebottom                         = theme.confdir .. "/icons/tilebottom.png"
theme.layout_tiletop                            = theme.confdir .. "/icons/tiletop.png"
theme.layout_fairv                              = theme.confdir .. "/icons/fairv.png"
theme.layout_fairh                              = theme.confdir .. "/icons/fairh.png"
theme.layout_spiral                             = theme.confdir .. "/icons/spiral.png"
theme.layout_dwindle                            = theme.confdir .. "/icons/dwindle.png"
theme.layout_max                                = theme.confdir .. "/icons/max.png"
theme.layout_fullscreen                         = theme.confdir .. "/icons/fullscreen.png"
theme.layout_magnifier                          = theme.confdir .. "/icons/magnifier.png"
theme.layout_floating                           = theme.confdir .. "/icons/floating.png"
theme.titlebar_close_button_normal              = theme.confdir .. "/icons/titlebar/close_normal.png"
theme.titlebar_close_button_focus               = theme.confdir .. "/icons/titlebar/close_focus.png"
theme.titlebar_minimize_button_normal           = theme.confdir .. "/icons/titlebar/minimize_normal.png"
theme.titlebar_minimize_button_focus            = theme.confdir .. "/icons/titlebar/minimize_focus.png"
theme.titlebar_ontop_button_normal_inactive     = theme.confdir .. "/icons/titlebar/ontop_normal_inactive.png"
theme.titlebar_ontop_button_focus_inactive      = theme.confdir .. "/icons/titlebar/ontop_focus_inactive.png"
theme.titlebar_ontop_button_normal_active       = theme.confdir .. "/icons/titlebar/ontop_normal_active.png"
theme.titlebar_ontop_button_focus_active        = theme.confdir .. "/icons/titlebar/ontop_focus_active.png"
theme.titlebar_sticky_button_normal_inactive    = theme.confdir .. "/icons/titlebar/sticky_normal_inactive.png"
theme.titlebar_sticky_button_focus_inactive     = theme.confdir .. "/icons/titlebar/sticky_focus_inactive.png"
theme.titlebar_sticky_button_normal_active      = theme.confdir .. "/icons/titlebar/sticky_normal_active.png"
theme.titlebar_sticky_button_focus_active       = theme.confdir .. "/icons/titlebar/sticky_focus_active.png"
theme.titlebar_floating_button_normal_inactive  = theme.confdir .. "/icons/titlebar/floating_normal_inactive.png"
theme.titlebar_floating_button_focus_inactive   = theme.confdir .. "/icons/titlebar/floating_focus_inactive.png"
theme.titlebar_floating_button_normal_active    = theme.confdir .. "/icons/titlebar/floating_normal_active.png"
theme.titlebar_floating_button_focus_active     = theme.confdir .. "/icons/titlebar/floating_focus_active.png"
theme.titlebar_maximized_button_normal_inactive = theme.confdir .. "/icons/titlebar/maximized_normal_inactive.png"
theme.titlebar_maximized_button_focus_inactive  = theme.confdir .. "/icons/titlebar/maximized_focus_inactive.png"
theme.titlebar_maximized_button_normal_active   = theme.confdir .. "/icons/titlebar/maximized_normal_active.png"
theme.titlebar_maximized_button_focus_active    = theme.confdir .. "/icons/titlebar/maximized_focus_active.png"
theme.taglist_squares_sel                       = theme.confdir .. "/icons/square_a.png"
theme.taglist_squares_unsel                     = theme.confdir .. "/icons/square_b.png"

theme.tasklist_plain_task_name                  = true
theme.tasklist_disable_icon                     = true
theme.useless_gap                               = 0

theme.universal_size                            = 32

theme.Spacing                                   = theme.universal_size * (2 / 3)
theme.useless_gap                               = theme.universal_size / 5
theme.gap_single_client                         = true

theme.border_width                              = theme.universal_size / 20
theme.border_normal                             = gray
theme.border_focus                              = white
theme.border_marked                             = black

awful.util.tagnames                             = { "  ", "  ", "  ", "  ", "  ", "  ", "  ", "  ", "  " }

local keyboardlayout                            = awful.widget.keyboardlayout:new()

local markup                                    = lain.util.markup

-- Textclock
os.setlocale(os.getenv("LANG")) -- to localize the clock
local clock = awful.widget.watch(
    "date +'%a %d %b %R'", 60,
    function(widget, stdout)
        widget:set_markup(markup.fontfg(theme.font, black, stdout))
    end
)

-- Calendar
theme.cal = lain.widget.cal({
    attach_to = { clock },
    three = true,
    icons = "",
    notification_preset = {
        font = font,
        fg   = black,
        bg   = white
    }
})

-- Battery
local bat = lain.widget.bat({
    timeout = 10,
    battery = "BAT1",
    ac = "ACAD",
    settings = function()
        local perc = bat_now.perc ~= "N/A" and bat_now.perc .. "%" or bat_now.perc

        if bat_now.ac_status == 1 then
            perc = perc .. " AC"
        end

        widget:set_markup(markup.fontfg(theme.font, black, "Bat: " .. perc))

        bat_notification_charged_preset = {
            title   = "Battery full",
            text    = "You can unplug the cable!",
            timeout = 15,
            fg      = black,
            bg      = cyan
        }

        bat_notification_low_preset = {
            title   = "Battery low",
            text    = "Plug the cable!",
            timeout = 15,
            fg      = black,
            bg      = orange
        }

        bat_notification_critical_preset = {
            title   = "Battery exhausted",
            text    = "Shutdown imminent!",
            timeout = 15,
            fg      = black,
            bg      = red
        }
    end,
})

-- Net
local net = lain.widget.net({
    units = 128,
    settings = function()
        local dynamic = function(num)
            if num > 1000000 then
                return string.format("%.1f GB/s", num / 1000000)
            elseif num > 1000 then
                return string.format("%.1f MB/s", num / 1000)
            end
            return string.format("%.1f KB/s", num)
        end

        widget:set_markup(markup.font(theme.font,
            markup(black, "Net: " .. " " .. dynamic(tonumber(net_now.received)))
            .. " " ..
            markup(black, " " .. dynamic(tonumber(net_now.sent)))))
    end
})

-- MEM
local mem = lain.widget.mem({
    settings = function()
        widget:set_markup(markup.fontfg(theme.font, black, "Mem: " .. mem_now.perc .. "%"))
    end
})

-- CPU
local cpu = lain.widget.cpu({
    settings = function()
        widget:set_markup(markup.fontfg(theme.font, black, "Cpu: " .. cpu_now.usage .. "%"))
    end
})

-- CPU temp
local temp = lain.widget.temp({
    tempfile = '/sys/devices/virtual/thermal/thermal_zone1/temp',
    settings = function()
        widget:set_markup(markup.fontfg(theme.font, black, "Temp: " .. coretemp_now .. "°C"))
    end
})

-- Weather
weather = lain.widget.weather({
    APPID = const.APPID,
    lat = const.lat,
    lon = const.lon,
    units = "metric",
    notification_preset = { font = font, fg = white, bg = red },
    weather_na_markup = markup.fontfg(theme.font, white, "N/A "),
    settings = function()
        descr = weather_now["weather"][1]["description"]:lower()
        units = math.floor(weather_now["main"]["temp"])
        widget:set_markup(markup.fontfg(theme.font, white, units .. "°C with " .. descr))
    end,
    notification_text_fun = function(wn)
        local day = string.format("%16s ", os.date('%A, %I %p', wn['dt']))
        local temp = math.floor(wn["main"]["temp"])
        local desc = wn["weather"][1]["description"]
        return string.format("<b>%s</b>: %d°C with %s", day, temp, desc)
    end
})

-- ALSA volume
theme.volume = lain.widget.alsa({
    settings = function()
        if volume_now.status == "off" then
            volume_now.level = volume_now.level .. "M"
        end

        widget:set_markup(markup.fontfg(theme.font, white, "Vol: " .. volume_now.level .. "%"))
    end
})

local widget_powerliner = function(widget_to_container, color)
    return wibox.widget {
        {
            {
                widget_to_container,
                layout = wibox.layout.align.horizontal
            },
            right  = 15,
            left   = 15,
            widget = wibox.container.margin
        },
        widget = wibox.container.background,
        bg = color or '#ffffff',
        shape = function(cr, width, height)
            local shape = gears.shape.powerline(cr, width, height, height / -2)
            return shape
        end
    }
end

function theme.at_screen_connect(s)
    -- Quake application
    s.quake = lain.util.quake({ app = awful.util.terminal })

    -- If wallpaper is a function, call it with the screen
    local wallpaper = theme.wallpaper
    if type(wallpaper) == "function" then
        wallpaper = wallpaper(s)
    end
    gears.wallpaper.maximized(wallpaper, s, true)

    -- Tags
    awful.tag(awful.util.tagnames, s, awful.layout.layouts[1])

    -- Create a promptbox for each screen
    s.mypromptbox = awful.widget.prompt()
    -- Create an imagebox widget which will contains an icon indicating which layout we're using.
    -- We need one layoutbox per screen.
    s.mylayoutbox = awful.widget.layoutbox(s)
    s.mylayoutbox:buttons(my_table.join(
        awful.button({}, 1, function() awful.layout.inc(1) end),
        awful.button({}, 2, function() awful.layout.set(awful.layout.layouts[1]) end),
        awful.button({}, 3, function() awful.layout.inc(-1) end),
        awful.button({}, 4, function() awful.layout.inc(1) end),
        awful.button({}, 5, function() awful.layout.inc(-1) end)))

    -- Create a taglist widget

    local tag_bg_colors = { white, cyan, purple, blue, orange, green, red, gray, black }
    local tag_fg_colors = { black, black, black, black, black, black, white, white, white }

    local update_tags = function(self, t)
        if t.selected then
            self.bg = tag_fg_colors[t.index]
            self.fg = tag_bg_colors[t.index]
        else
            self.bg = tag_bg_colors[t.index]
            self.fg = tag_fg_colors[t.index]
        end
    end

    s.mytaglist = awful.widget.taglist {
        screen          = s,
        filter          = awful.widget.taglist.filter.all,
        buttons         = awful.util.taglist_buttons,
        widget_template = {
            {
                {
                    id     = 'text_role',
                    widget = wibox.widget.textbox,
                },
                right  = 8,
                left   = 8,
                widget = wibox.container.margin,
            },
            widget = wibox.container.background,
            shape = gears.shape.powerline,
            id = 'background',
            create_callback = update_tags,
            update_callback = update_tags,
        },
        layout          = {
            spacing = -10,
            layout = wibox.layout.fixed.horizontal
        }
    }


    -- s.mytaglist = awful.widget.taglist(s, awful.widget.taglist.filter.all, awful.util.taglist_buttons)

    -- Create a tasklist widget
    s.mytasklist = awful.widget.tasklist(s, awful.widget.tasklist.filter.currenttags, awful.util.tasklist_buttons)

    -- Create the wibox
    s.mywibox = awful.wibar({
        position = "top",
        screen = s,
        height = dpi(19),
        bg = theme.bg_normal .. "00",
        fg = theme
            .fg_normal,
        visible = false
    })

    -- Add widgets to the wibox
    s.mywibox:setup {
        layout = wibox.layout.align.horizontal,
        { -- Left widgets
            layout = wibox.layout.fixed.horizontal,
            s.mytaglist,
            s.mypromptbox,
        },
        --s.mytasklist, -- Middle widget
        nil,
        { -- Right widgets
            layout = wibox.layout.fixed.horizontal,
            spacing = -10,
            widget_powerliner(wibox.widget {
                layout = wibox.layout.fixed.horizontal,
                keyboardlayout,
                wibox.widget.systray(),
            }, black),
            widget_powerliner(theme.volume, gray),
            widget_powerliner(weather, red),
            widget_powerliner(temp.widget, green),
            widget_powerliner(cpu.widget, orange),
            widget_powerliner(mem.widget, blue),
            widget_powerliner(net.widget, purple),
            widget_powerliner(bat.widget, cyan),
            widget_powerliner(clock, white),
        },
    }

    -- Create the bottom wibox
    s.mybottomwibox = awful.wibar({
        position = "bottom",
        screen = s,
        border_width = 0,
        height = dpi(20),
        bg = theme
            .bg_normal,
        fg = theme.fg_normal
    })

    -- Add widgets to the bottom wibox
    s.mybottomwibox:setup {
        layout = wibox.layout.align.horizontal,
        { -- Left widgets
            layout = wibox.layout.fixed.horizontal,
        },
        s.mytasklist, -- Middle widget
        {             -- Right widgets
            layout = wibox.layout.fixed.horizontal,
            s.mylayoutbox,
        },
    }
end

return theme
