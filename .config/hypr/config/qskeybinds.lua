-- ===========================================
-- qskeybinds.lua — Quickshell (qs) bindings
-- ===========================================

local mainMod = "SUPER"
local altMod  = "ALT + CTRL"
local qs      = "qs -c noctalia-shell ipc call"

hl.bind(mainMod .. " + W",          hl.dsp.exec_cmd(qs .. " wallpaper toggle"))
hl.bind(mainMod .. " + SHIFT + W",  hl.dsp.exec_cmd(qs .. " plugin:wallcards toggle"))
hl.bind("ALT + W",                  hl.dsp.exec_cmd(qs .. " wallpaper random $monitor"))
hl.bind(mainMod .. " + M",          hl.dsp.exec_cmd(qs .. " controlCenter toggle"))
hl.bind(mainMod .. " + SHIFT + C",  hl.dsp.exec_cmd(qs .. " plugin:clipper toggle"))
hl.bind(mainMod .. " + SHIFT + M",  hl.dsp.exec_cmd(qs .. " plugin:screen-toolkit toggle"))
hl.bind(mainMod .. " + D",          hl.dsp.exec_cmd(qs .. " launcher toggle"))
hl.bind(mainMod .. " + C",          hl.dsp.exec_cmd(qs .. " launcher clipboard"))
hl.bind(mainMod .. " + R",          hl.dsp.exec_cmd(qs .. " launcher command"))
hl.bind(mainMod .. " + N",          hl.dsp.exec_cmd(qs .. " nightLight toggle"))
hl.bind(altMod  .. " + N",          hl.dsp.exec_cmd(qs .. " settings openTab display/1"))
hl.bind(mainMod .. " + A",          hl.dsp.exec_cmd(qs .. " plugin:assistant-panel toggle"))
-- hl.bind(mainMod .. " + L",       hl.dsp.exec_cmd(qs .. " sessionMenu toggle"))
