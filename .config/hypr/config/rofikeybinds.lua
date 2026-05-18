-- ===========================================
-- rofikeybinds.lua — Rofi / Wofi bindings
-- (подключается из hyprland.lua при необходимости)
-- ===========================================

local mainMod = "SUPER"
local altMod  = "ALT + CTRL"
local home    = os.getenv("HOME")

local menu       = home .. "/.config/rofi/launcher/rofi-launcher"
local bluetooth  = home .. "/.config/rofi/network/rofi-bluetooth"
local network    = home .. "/.config/rofi/network/rofi-network"
local nightshift = home .. "/.config/rofi/nightshift/rofi-nightshift"
local wallpicker = home .. "/.config/wofi/wofi-wallpaper"
local find       = home .. "/.config/rofi/finder/rofi-finder"
local clipboard  = home .. "/.config/rofi/clipboard/rofi-clipsnip"

local waybar       = home .. "/bin/waybar/wayhide"
local notifications = "swaync-client -t -sw"
local powermenu    = home .. "/bin/waybar/waypower"
local wallpaper    = home .. "/bin/others/swaybg-random"

-- SUPER
hl.bind(mainMod .. " + D", hl.dsp.exec_cmd(menu))
hl.bind(mainMod .. " + W", hl.dsp.exec_cmd(wallpaper))
hl.bind(mainMod .. " + O", hl.dsp.exec_cmd(waybar))
hl.bind(mainMod .. " + N", hl.dsp.exec_cmd(nightshift .. " toggle"))

-- ALT
hl.bind("ALT + L", hl.dsp.exec_cmd("hyprlock"))
hl.bind("ALT + P", hl.dsp.exec_cmd(powermenu))
hl.bind("ALT + B", hl.dsp.exec_cmd(bluetooth))
hl.bind("ALT + N", hl.dsp.exec_cmd(network))
hl.bind("ALT + M", hl.dsp.exec_cmd(notifications))
hl.bind("ALT + C", hl.dsp.exec_cmd(clipboard))
hl.bind("ALT + W", hl.dsp.exec_cmd(wallpicker))
hl.bind("ALT + F", hl.dsp.exec_cmd(find))

-- ALT+CTRL
hl.bind(altMod .. " + N", hl.dsp.exec_cmd(nightshift .. " config"))
