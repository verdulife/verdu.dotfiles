-- See https://wiki.hypr.land/Configuring/Basics/Monitors/
-- List current monitors and supported resolutions with: hyprctl monitors all

-- Monitor scale is Hyprland's scale for the output. It sizes everything
-- Wayland-native, accepts fractions (1.6, 1.75), and applies immediately.
-- "auto" lets Hyprland pick per display.
local omarchy_monitor_scale = "auto"

-- Explicit layout. The HDMI connector feeds the LEFT screen and the DVI one the
-- RIGHT screen, but "auto" assigns positions by connector order and put them the
-- other way round. 1920x1080 each, so the right one starts at x=1920.
hl.monitor({ output = "HDMI-A-3", mode = "preferred", position = "0x0", scale = omarchy_monitor_scale })
hl.monitor({ output = "DVI-D-1", mode = "preferred", position = "1920x0", scale = omarchy_monitor_scale })

-- Fallback for anything else (a panel plugged in later, the laptop's own screen).
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = omarchy_monitor_scale })

-- Configure a specific monitor.
-- hl.monitor({ output = "DP-2", mode = "2560x1440@144", position = "0x0", scale = 1 })

-- Portrait/rotated secondary monitor (transform: 1 = 90°, 3 = 270°).
-- hl.monitor({ output = "DP-2", mode = "preferred", position = "auto", scale = 1, transform = 1 })

-- GDK scale is GDK_SCALE, the factor GTK draws its own UI at. It's what
-- sizes X11/XWayland windows, which Omarchy leaves unscaled so they stay
-- crisp instead of being stretched by the compositor. GTK only honors whole
-- numbers, so use the nearest integer to the monitor scale, and restart an
-- app for a change to reach it.
local omarchy_gdk_scale = 2
hl.env("GDK_SCALE", tostring(omarchy_gdk_scale))
