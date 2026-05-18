-- ===========================================
-- autostart.lua
-- ===========================================

hl.on("hyprland.start", function()
	local home = os.getenv("HOME")

	-- System / dbus
	hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP DISPLAY")

	-- Hardware
	hl.exec_cmd(home .. "/bin/others/bt_autoconnect.sh") -- Auto-connect Bluetooth devices
	hl.exec_cmd(home .. "/bin/hypr/capslockd") -- Capslock monitoring daemon
	hl.exec_cmd(home .. "/bin/hypr/hyprxkb") -- Keyboard layout control

	-- Desktop environment
	hl.exec_cmd("qs -c noctalia-shell")
	-- hl.exec_cmd("waybar")
	-- hl.exec_cmd("swayosd-server -s ~/.config/swayosd/style.css")
	hl.exec_cmd("hypridle")
	-- hl.exec_cmd(home .. "/bin/others/swaybg-random")
	hl.exec_cmd("wl-paste --watch cliphist store") -- Clipboard history
	-- hl.exec_cmd("sleep 12 && swaync")

	-- Apps and utilities
	-- hl.exec_cmd(home .. "/.config/rofi/nightshift/rofi-nightshift on")
	hl.exec_cmd("sh -c '[ -f " .. home .. "/.cache/hyprvisuals ] && " .. home .. "/bin/hypr/hyprvisuals'")
	hl.exec_cmd("sh -c 'sleep 10 && " .. home .. "/apps/sendtompv/install.sh'")
	hl.exec_cmd(home .. "/git/personal/twtv/twtv-notify")
	hl.exec_cmd(home .. "git/personal/arch-greeting/greetingd")

	-- Autostart apps on special workspaces
	-- hl.exec_cmd("[workspace special:magic silent] zen-browser")
end)
