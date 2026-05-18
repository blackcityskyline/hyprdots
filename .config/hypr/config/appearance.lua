-- ===========================================
-- appearance.lua
-- ===========================================

-- ===========================================
-- General
-- ===========================================
hl.config({
	general = {
		gaps_in = 4,
		gaps_out = 6,
		border_size = 0, -- No borders, shadows only
		layout = "dwindle",
		resize_on_border = true,
		extend_border_grab_area = 15,
		allow_tearing = false,
		col = {
			active_border = "rgb(565f89)", -- Active window border (blue-grey)
			inactive_border = "rgb(2E2E34)", -- Inactive window border (dark grey)
		},
	},
})

-- ===========================================
-- Decorations
-- ===========================================
hl.config({
	decoration = {
		rounding = 12,
		active_opacity = 0.98,
		inactive_opacity = 0.92,

		shadow = {
			enabled = true,
			range = 18,
			render_power = 3,
			color = "rgba(0,0,0,0.8)",
			offset = { 0, 8 },
		},

		blur = {
			enabled = true,
			size = 3,
			passes = 1,
			new_optimizations = true,
			xray = false,
			ignore_opacity = false,
			noise = 0,
			contrast = 1.0,
			brightness = 1.0,
			vibrancy = 0.1,
			vibrancy_darkness = 0.2,
			popups = true,
			popups_ignorealpha = 0.6,
		},

		dim_inactive = true,
		dim_strength = 0.08,
		dim_special = 0.3,
		dim_around = 0.5,
	},
})

-- ===========================================
-- Animations
-- ===========================================
hl.config({ animations = { enabled = true } })

-- Bezier curves
hl.curve("material", { type = "bezier", points = { { 0.4, 0.0 }, { 0.2, 1.0 } } })
hl.curve("smooth", { type = "bezier", points = { { 0.4, 0.0 }, { 0.2, 1.0 } } })
hl.curve("overshot", { type = "bezier", points = { { 0.13, 0.99 }, { 0.29, 1.0 } } })
hl.curve("easeOutQuint", { type = "bezier", points = { { 0.23, 1 }, { 0.32, 1 } } })
hl.curve("easeInOutCubic", { type = "bezier", points = { { 0.65, 0.05 }, { 0.36, 1 } } })
hl.curve("quick", { type = "bezier", points = { { 0.15, 0 }, { 0.1, 1 } } })
hl.curve("linear", { type = "bezier", points = { { 0, 0 }, { 1, 1 } } })

-- Border (disabled for performance)
hl.animation({ leaf = "border", enabled = false })
hl.animation({ leaf = "borderangle", enabled = false })

-- Layers
hl.animation({ leaf = "layers", enabled = true, speed = 2, bezier = "smooth" })
hl.animation({ leaf = "layersIn", enabled = true, speed = 2, bezier = "smooth" })
hl.animation({ leaf = "layersOut", enabled = true, speed = 2, bezier = "smooth" })

-- Windows
hl.animation({ leaf = "windows", enabled = true, speed = 1.5, bezier = "smooth", style = "popin 85%" })
hl.animation({ leaf = "windowsIn", enabled = true, speed = 1.5, bezier = "smooth", style = "popin 85%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 1.5, bezier = "smooth", style = "popin 85%" })
hl.animation({ leaf = "windowsMove", enabled = true, speed = 1.5, bezier = "smooth", style = "popin 85%" })

-- Fade
hl.animation({ leaf = "fade", enabled = true, speed = 2, bezier = "smooth" })
hl.animation({ leaf = "fadeIn", enabled = true, speed = 1, bezier = "smooth" })
hl.animation({ leaf = "fadeOut", enabled = true, speed = 1, bezier = "smooth" })
hl.animation({ leaf = "fadeSwitch", enabled = false }) -- Disabled for performance
hl.animation({ leaf = "fadeShadow", enabled = true, speed = 1, bezier = "smooth" })
hl.animation({ leaf = "fadeDim", enabled = true, speed = 1, bezier = "smooth" })
hl.animation({ leaf = "fadeLayers", enabled = true, speed = 1, bezier = "smooth" })

-- Workspaces
hl.animation({ leaf = "workspaces", enabled = true, speed = 1, bezier = "quick", style = "slidefade" })
hl.animation({ leaf = "workspacesIn", enabled = true, speed = 1, bezier = "quick" })
hl.animation({ leaf = "workspacesOut", enabled = true, speed = 1, bezier = "quick" })
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 1.5, bezier = "overshot", style = "slidevert" })
hl.animation({ leaf = "specialWorkspaceIn", enabled = true, speed = 1, bezier = "smooth" })
hl.animation({ leaf = "specialWorkspaceOut", enabled = true, speed = 1, bezier = "smooth" })

-- ===========================================
-- Layouts
-- ===========================================
hl.config({
	dwindle = {
		preserve_split = true,
		smart_split = false, -- Disabled for performance
		smart_resizing = true,
		permanent_direction_override = false,
		special_scale_factor = 0.96,
		split_width_multiplier = 1.2,
		use_active_for_splits = true,
		force_split = 2,
		default_split_ratio = 1.0,
	},
})

hl.config({
	master = {
		new_status = "master",
		new_on_top = true,
		orientation = "left",
		smart_resizing = true,
		drop_at_cursor = false,
		mfact = 0.5,
	},
})

hl.config({
	scrolling = {
		fullscreen_on_one_column = true,
		column_width = 1.0,
		direction = "right",
	},
})

-- ===========================================
-- Workspaces
-- ===========================================
hl.workspace_rule({ workspace = "1", default = true })
hl.workspace_rule({ workspace = "3" })
hl.workspace_rule({ workspace = "special:magic", on_created_empty = "alacritty" })
hl.workspace_rule({ workspace = "special:terminal", on_created_empty = "alacritty" })
hl.workspace_rule({ workspace = "10", layout = "scrolling", animation = "slide" })

-- ===========================================
-- Window rules
-- ===========================================

-- Suppress maximize events (universal)
hl.window_rule({
	name = "suppress-maximize",
	match = { class = ".*" },
	suppress_event = "maximize",
})

-- Fix XWayland dragging
hl.window_rule({
	name = "fix-xwayland-drag",
	match = { class = "^$", title = "^$", xwayland = true, float = true, fullscreen = false, pin = false },
	no_focus = true,
})

-- Browsers — no blur, opaque
hl.window_rule({
	match = { class = "^(zen|brave|firefox|helium)$" },
	no_blur = true,
	opacity = "1.0 override 1.0 override",
})

-- Terminals — blur enabled
hl.window_rule({ match = { class = "^(kitty|alacritty|foot)$" }, no_blur = false })

-- Waypaper
hl.window_rule({
	match = { class = "^(waypaper)$" },
	float = true,
	move = { 100, 200 },
	size = { 1000, 700 },
	border_size = 0,
	rounding = 16,
	opacity = "0.95 override",
	stay_focused = true,
	no_blur = true,
})

-- File managers
hl.window_rule({
	match = { class = "^(Thunar|pcmanfm)$" },
	float = false,
	move = { 100, 200 },
	size = { 1000, 700 },
	rounding = 14,
	opacity = "0.96 override",
	no_blur = true,
})

-- Control panels
hl.window_rule({
	match = { class = "^(org.pulseaudio.pavucontrol|qt5ct|qt6ct)$" },
	float = true,
	move = { 100, 200 },
	size = { 900, 550 },
	rounding = 12,
	opacity = "1.0 override 1.0 override",
	stay_focused = true,
	no_blur = true,
})

-- Network / Bluetooth
hl.window_rule({
	match = { class = "^(com.network.manager|com.ezratweaver.AdwBluetooth)$" },
	float = true,
	move = { 100, 200 },
	size = { 400, 330 },
	rounding = 12,
	opacity = "1.0 override 1.0 override",
	no_blur = true,
})

-- Messengers
hl.window_rule({
	match = { class = "^(discord|org.telegram.desktop)$" },
	float = false,
	center = true,
	size = { 1100, 750 },
	rounding = 12,
	opacity = "1.0 override 1.0 override",
	no_blur = true,
})

-- Floating terminals
hl.window_rule({
	match = { title = "^(float-term|popup-term)$" },
	float = true,
	move = { 100, 200 },
	size = { 1100, 650 },
	rounding = 12,
	opacity = "0.94 override",
})

-- System monitors
hl.window_rule({
	match = { class = "^(htop|btop|nvtop|neohtop)$" },
	float = false,
	rounding = 10,
	opacity = "0.94 override",
})

-- Media viewers
hl.window_rule({
	match = { class = "^(gwenview|feh|imv|mpv|vlc)$" },
	float = true,
	center = true,
	rounding = 10,
	opacity = "1.0 override 1.0 override",
	no_blur = true,
})
hl.window_rule({ match = { class = "^(gwenview|feh|imv)$" }, size = { 900, 700 } })

-- Launchers
hl.window_rule({
	match = { class = "^(rofi|wofi|tofi)$" },
	float = true,
	move = { 100, 200 },
	rounding = 12,
	opacity = "1.0 override",
	no_blur = true,
})

-- Picture-in-Picture
hl.window_rule({
	match = { title = "^(Picture-in-Picture|PiP)$" },
	float = true,
	pin = true,
	rounding = 8,
	opacity = "1.0 override 1.0 override",
	size = { 480, 270 },
	no_blur = true,
})

-- Wrapped apps (Flatpak)
hl.window_rule({
	match = { class = "^\\..*-wrapped$" },
	float = true,
	center = true,
	rounding = 12,
	opacity = "0.98 override",
	no_blur = true,
})

-- Kdenlive
hl.window_rule({
	match = { class = "^(org.kde.kdenlive)$" },
	float = false,
	center = true,
	no_blur = true,
	opacity = "1.0 override 1.0 override",
})

-- Minecraft
hl.window_rule({
	match = { class = "^(Minecraft)$" },
	float = true,
	center = true,
	no_blur = true,
	opacity = "1.0 override 1.0 override",
	no_anim = true,
	confine_pointer = true, -- NEW 0.55: конфайнит курсор внутри окна
})

-- YouTube Music
hl.window_rule({
	match = { class = "^(com.github.th_ch.youtube_music)$" },
	float = false,
	no_blur = true,
	opacity = "1.0 override 1.0 override",
	no_anim = true,
	rounding = 12,
})

-- Generic system dialogs
hl.window_rule({
	match = { title = "^(Bluetooth|Network|Wi-Fi|Settings|Audio|Media viewer|Confirm|wiremix)$" },
	float = true,
	center = true,
	stay_focused = false,
})
hl.window_rule({ match = { title = "^(Media viewer)$" }, size = { 1000, 700 } })

-- ===========================================
-- Layer rules
-- ===========================================

-- Waybar — no blur
hl.layer_rule({ match = { namespace = "^(waybar)$" }, blur = false, ignore_alpha = 0.2 })

-- Launchers — blur
hl.layer_rule({
	match = { namespace = "^(rofi|wofi|swayosd)$" },
	blur = true,
	ignore_alpha = 0.2,
	animation = "popin 95%",
})

-- Notifications
hl.layer_rule({ match = { namespace = "^(notifications)$" }, blur = true, ignore_alpha = 0.3 })

-- Terminal layers
hl.layer_rule({ match = { namespace = "^(kitty)$" }, blur = true, ignore_alpha = 0.1 })
hl.layer_rule({ match = { namespace = "^(alacritty)$" }, blur = true, ignore_alpha = 0.1 })

-- Logout dialog
hl.layer_rule({
	match = { namespace = "logout_dialog" },
	blur = true,
	animation = "slide right",
	dim_around = true,
	xray = false,
})

-- Swaync
hl.layer_rule({
	match = { namespace = "swaync-control-center" },
	blur = true,
	ignore_alpha = 0.2,
	animation = "slide top",
})
hl.layer_rule({
	match = { namespace = "swaync-notification-window" },
	blur = true,
	ignore_alpha = 0.2,
	animation = "slide top",
})

-- Noctalia background (раскомментировать при необходимости)
-- hl.layer_rule({ match = { namespace = "noctalia-background-.*" }, blur = true, ignore_alpha = 0.2 })
