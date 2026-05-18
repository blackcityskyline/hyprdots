-- ===========================================
-- misc.lua — Разные настройки и производительность
-- ===========================================

hl.config({
	render = {
		direct_scanout = true,
	},
})

hl.config({
	misc = {
		-- Визуальные настройки
		force_default_wallpaper = 0,
		disable_hyprland_logo = true,
		disable_splash_rendering = true,

		-- Производительность
		vrr = 1, -- Fullscreen only, для стабильности
		mouse_move_enables_dpms = true,
		key_press_enables_dpms = true,
		always_follow_on_dnd = true,
		layers_hog_keyboard_focus = true,
		animate_manual_resizes = false, -- Disabled for better resize performance
		animate_mouse_windowdragging = false, -- Disabled for smoother dragging
		disable_autoreload = false,

		-- Фокус и управление окнами
		focus_on_activate = true,
		mouse_move_focuses_monitor = true,

		-- Дополнительное поведение
		allow_session_lock_restore = true,
		background_color = "rgb(000000)",
		close_special_on_empty = true,
		on_focus_under_fullscreen = 1,
		initial_workspace_tracking = 1,
		middle_click_paste = true,

		-- Уменьшение использования ресурсов
		enable_swallow = true,
	},
})
