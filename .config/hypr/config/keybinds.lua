-- ===========================================
-- keybinds.lua
-- ===========================================

local mainMod = "SUPER"
local altMod = "ALT + CTRL"
local mainModS = "SUPER + CTRL"
local home = os.getenv("HOME")

-- Core apps
local terminal = "alacritty"
local filemanager = "pcmanfm"
local browser = "helium-browser"
local telegram = "Telegram -- " .. home .. "/.config/telegram-desktop/themes/noctalia.tdesktop-theme"
local hiddify = home .. "/apps/Hiddify-Linux-x64-AppImage.AppImage"

-- Utilities / Scripts
local powermenu = home .. "/bin/waybar/waypower"
local bible = home .. "/bin/others/bible"
local stylus = home .. "/bin/others/update-stylus"
local xkblayout = home .. "/bin/hypr/hyprxkblayout"
local audioctl = home .. "/bin/hypr/audioctl"
local backlightctl = home .. "/bin/hypr/backlightctl"
local scr_area = 'grim -g "$(slurp)" - | wl-copy'
local scr_full = "grim - | wl-copy"

-- ===========================================
-- SUPER — Core bindings
-- ===========================================

-- Apps
hl.bind(mainMod .. " + Return", hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(filemanager))
hl.bind(mainMod .. " + B", hl.dsp.exec_cmd(browser))
hl.bind(mainMod .. " + T", hl.dsp.exec_cmd(telegram))
hl.bind(mainMod .. " + I", hl.dsp.exec_cmd("foot wiremix"))
hl.bind(mainMod .. " + V", hl.dsp.exec_cmd(hiddify))
hl.bind(mainMod .. " + O", hl.dsp.exec_cmd(stylus))

-- Desktop
-- hl.bind(mainMod .. " + Space", hl.dsp.exec_cmd(xkblayout))
hl.bind(mainMod .. " + KP_Home", hl.dsp.exit())

-- Window management
hl.bind(mainMod .. " + Q", hl.dsp.window.close())
hl.bind(mainModS .. " + Q", hl.dsp.window.close({ force = true }))
hl.bind(mainMod .. " + Z", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen())
hl.bind(mainMod .. " + P", hl.dsp.window.pseudo())
hl.bind(mainMod .. " + F5", hl.dsp.layout("rotatesplit")) -- rotatesplit (0.55)
hl.bind(mainMod .. " + F6", hl.dsp.layout("togglesplit"))
hl.bind(mainMod .. " + G", hl.dsp.group.toggle())
hl.bind(mainMod .. " + Tab", hl.dsp.group.next())

-- ===========================================
-- ALT — Utilities and menus
-- ===========================================

-- hl.bind("ALT + L", hl.dsp.exec_cmd("hyprlock"))
hl.bind("ALT + P", hl.dsp.exec_cmd(powermenu))
hl.bind("ALT + S", hl.dsp.exec_cmd(scr_area))
hl.bind("ALT + A", hl.dsp.exec_cmd(scr_full))

hl.bind("ALT + Tab", hl.dsp.window.cycle_next())
hl.bind("ALT + SHIFT + Tab", hl.dsp.window.cycle_next({ prev = true }))

-- ALT+CTRL
hl.bind(altMod .. " + B", hl.dsp.exec_cmd(bible))

-- ===========================================
-- Focus — arrow keys + vim keys
-- ===========================================

hl.bind(mainMod .. " + Left", hl.dsp.focus({ direction = "l" }))
hl.bind(mainMod .. " + Right", hl.dsp.focus({ direction = "r" }))
hl.bind(mainMod .. " + Up", hl.dsp.focus({ direction = "u" }))
hl.bind(mainMod .. " + Down", hl.dsp.focus({ direction = "d" }))

hl.bind(mainMod .. " + H", hl.dsp.focus({ direction = "l" }))
hl.bind(mainMod .. " + L", hl.dsp.focus({ direction = "r" }))
hl.bind(mainMod .. " + K", hl.dsp.focus({ direction = "u" }))
hl.bind(mainMod .. " + J", hl.dsp.focus({ direction = "d" }))

-- ===========================================
-- Resize — SUPER+CTRL + arrows / vim keys
-- ===========================================
hl.bind(mainModS .. " + Left", hl.dsp.window.resize({ x = -50, y = 0, relative = true }), { repeating = true })
hl.bind(mainModS .. " + Right", hl.dsp.window.resize({ x = 50, y = 0, relative = true }), { repeating = true })
hl.bind(mainModS .. " + Up", hl.dsp.window.resize({ x = 0, y = -50, relative = true }), { repeating = true })
hl.bind(mainModS .. " + Down", hl.dsp.window.resize({ x = 0, y = 50, relative = true }), { repeating = true })

hl.bind(mainModS .. " + H", hl.dsp.window.resize({ x = -50, y = 0, relative = true }), { repeating = true })
hl.bind(mainModS .. " + L", hl.dsp.window.resize({ x = 50, y = 0, relative = true }), { repeating = true })
hl.bind(mainModS .. " + K", hl.dsp.window.resize({ x = 0, y = -50, relative = true }), { repeating = true })
hl.bind(mainModS .. " + J", hl.dsp.window.resize({ x = 0, y = 50, relative = true }), { repeating = true })

-- ===========================================
-- Swap windows — SUPER+SHIFT + arrows / vim
-- ===========================================

hl.bind(mainMod .. " + SHIFT + Left", hl.dsp.window.move({ direction = "l", swap = true }))
hl.bind(mainMod .. " + SHIFT + Right", hl.dsp.window.move({ direction = "r", swap = true }))
hl.bind(mainMod .. " + SHIFT + Up", hl.dsp.window.move({ direction = "u", swap = true }))
hl.bind(mainMod .. " + SHIFT + Down", hl.dsp.window.move({ direction = "d", swap = true }))

hl.bind(mainMod .. " + SHIFT + H", hl.dsp.window.move({ direction = "l", swap = true }))
hl.bind(mainMod .. " + SHIFT + L", hl.dsp.window.move({ direction = "r", swap = true }))
hl.bind(mainMod .. " + SHIFT + K", hl.dsp.window.move({ direction = "u", swap = true }))
hl.bind(mainMod .. " + SHIFT + J", hl.dsp.window.move({ direction = "d", swap = true }))

-- ===========================================
-- Workspaces
-- ===========================================

-- Switch to workspace
for i = 1, 9 do
	hl.bind(mainMod .. " + " .. i, hl.dsp.focus({ workspace = i }))
end
hl.bind(mainMod .. " + 0", hl.dsp.focus({ workspace = 10 }))

-- Move window to workspace
for i = 1, 9 do
	hl.bind(altMod .. " + " .. i, hl.dsp.window.move({ workspace = i }))
end
hl.bind(altMod .. " + 0", hl.dsp.window.move({ workspace = 10 }))

-- Special workspaces
hl.bind(mainMod .. " + S", hl.dsp.workspace.toggle_special("magic"))
hl.bind(altMod .. " + CTRL + S", hl.dsp.window.move({ workspace = "special:magic" }))

-- special:terminal — открыть если нет, показать/скрыть
hl.bind(mainMod .. " + grave", function()
	local clients = hl.get_windows()
	local found = false
	for _, w in ipairs(clients) do
		if w.workspace and w.workspace.name == "special:terminal" then
			found = true
			break
		end
	end
	if not found then
		hl.exec_cmd("alacritty")
	end
	hl.dispatch(hl.dsp.workspace.toggle_special("terminal"))
end)
hl.bind(mainMod .. " + SHIFT + grave", hl.dsp.window.move({ workspace = "special:terminal" }))

-- ===========================================
-- Mouse bindings
-- ===========================================

hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }))
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- ===========================================
-- Media keys
-- ===========================================

-- Playback
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })

-- Volume
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd(audioctl .. " up"))
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd(audioctl .. " down"))
hl.bind("XF86AudioMute", hl.dsp.exec_cmd(audioctl .. " mute"))

-- Volume — sink management
hl.bind("SHIFT + XF86AudioRaiseVolume", hl.dsp.exec_cmd(audioctl .. " group 1 2"))
hl.bind("SHIFT + XF86AudioLowerVolume", hl.dsp.exec_cmd(audioctl .. " ungroup"))
hl.bind("SHIFT + XF86AudioMute", hl.dsp.exec_cmd(audioctl .. " sink-next"))

-- Brightness
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd(backlightctl .. " up"))
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd(backlightctl .. " down"))
hl.bind("XF86ScreenSaver", hl.dsp.exec_cmd(backlightctl .. " saver"))

-- Lid switch
hl.bind("switch:on:Lid Switch", hl.dsp.exec_cmd("systemctl suspend"), { locked = true })

-- ===========================================
-- Scrolling layout — testing
-- ===========================================

hl.bind(mainMod .. " + bracketleft", hl.dsp.layout("move -col"))
hl.bind(mainMod .. " + bracketright", hl.dsp.layout("move +col"))
hl.bind(mainMod .. " + SHIFT + bracketright", hl.dsp.layout("expel"))
hl.bind(mainMod .. " + SHIFT + bracketleft", hl.dsp.layout("consume"))
hl.bind(mainMod .. " + ALT + bracketleft", hl.dsp.layout("colresize -0.1"))
hl.bind(mainMod .. " + ALT + bracketright", hl.dsp.layout("colresize +0.1"))

-- hl.bind(mainMod .. " + Tab", hl.dsp.workspace.change("e+1"))
hl.bind(mainMod .. " + Tab", hl.dsp.exec_cmd("hyprctl dispatch hyprexpo:expo toggle"))
hl.bind(mainMod .. " + Tab", hl.dsp.focus({ workspace = "previous" }))
