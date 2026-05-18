-- ===========================================
-- input.lua
-- ===========================================

hl.config({
    input = {
        kb_layout  = "us,ru",
        kb_variant = "",
        kb_model   = "",
        kb_rules   = "",
        -- kb_options = "grp:win_space_toggle",

        follow_mouse              = 1,
        mouse_refocus             = false,
        float_switch_override_focus = 2,
        sensitivity               = 0,
        accel_profile             = "flat",
        numlock_by_default        = true,

        touchpad = {
            natural_scroll          = false,
            tap_to_click            = true,
            tap_and_drag            = true,
            drag_lock               = true,
            disable_while_typing    = true,
            middle_button_emulation = true,
            scroll_factor           = 0.5,
        },
    },
})

hl.config({
    gestures = {
        -- workspace_swipe = true,
    },
})

-- Per-device overrides
hl.device({
    name          = "logitech-m185-1",
    sensitivity   = 0,
    scroll_factor = 5.0,
})
