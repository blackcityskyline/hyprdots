-- ===========================================
-- hyprland.lua — main entry point
-- ===========================================

-- ===========================================
-- Monitor
-- ===========================================
hl.monitor({
	output = "",
	mode = "preferred",
	position = "auto",
	scale = "auto",
})

-- ===========================================
-- Environment variables
-- ===========================================

-- Cursor
hl.env("XCURSOR_THEME", "capitaine-cursors")
hl.env("XCURSOR_SIZE", "16")

-- GPU (Intel iGPU)
hl.env("LIBVA_DRIVER_NAME", "i965")
hl.env("LIBVA_DRIVERS_PATH", "/usr/lib/dri")
hl.env("VDPAU_DRIVER", "va_gl")
hl.env("WLR_NO_HARDWARE_CURSORS", "1")
hl.env("WLR_DRM_DEVICES", "/dev/dri/card2")
hl.env("VK_ICD_FILENAMES", "/usr/share/vulkan/icd.d/intel_hasvk_icd.x86_64.json")
hl.env("__EGL_VENDOR_LIBRARY_FILENAMES", "/usr/share/glvnd/egl_vendor.d/50_mesa.json")

-- Qt / GTK
hl.env("QT_QPA_PLATFORM", "wayland")
hl.env("QT_AUTO_SCREEN_SCALE_FACTOR", "1")
hl.env("QT_LOGGING_RULES", "qt.scenegraph.general=false")
hl.env("GTK_THEME", "adw-gtk3")
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")

-- Electron / Chromium
hl.env("ELECTRON_USE_VAAPI", "1")
hl.env("ELECTRON_USE_WAYLAND", "1")
hl.env("ELECTRON_USE_GL_DRIVER", "egl")
hl.env("ELECTRON_DISABLE_GPU", "0")
hl.env("ELECTRON_FORCE_GPU", "1")

-- Sync
hl.env("__GL_SYNC_TO_VBLANK", "1")
hl.env("WLR_DRM_NO_ATOMIC", "1")

-- Proxy (раскомментировать при необходимости)
-- hl.env("http_proxy",  "http://127.0.0.1:12334")
-- hl.env("https_proxy", "http://127.0.0.1:12334")
-- hl.env("all_proxy",   "socks5://127.0.0.1:12334")

-- ===========================================
-- Modules
-- ===========================================
require("config/autostart")
require("config/appearance")
require("config/keybinds")
require("config/input")
require("config/misc")
require("config/qskeybinds")
-- require("config/rofikeybinds")

-- Noctalia color theme
require("noctalia/noctalia-colors")
