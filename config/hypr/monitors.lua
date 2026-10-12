-- See https://wiki.hypr.land/Configuring/Basics/Monitors/
-- List current monitors and supported resolutions with: hyprctl monitors all

local omarchy_gdk_scale = 2
local omarchy_monitor_scale = 1.6

hl.env("GDK_SCALE", tostring(omarchy_gdk_scale))
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = omarchy_monitor_scale })

-- Configure a specific monitor.
-- hl.monitor({ output = "DP-2", mode = "2560x1440@144", position = "0x0", scale = 1 })

-- Portrait/rotated secondary monitor (transform: 1 = 90°, 3 = 270°).
-- hl.monitor({ output = "DP-2", mode = "preferred", position = "auto", scale = 1, transform = 1 })

-- Dell U2713HM mounted in portrait on the dock (matched by description so it works on any port).
-- transform = 3 rotates 270°; if the picture is ever upside down, use 1 instead.
hl.monitor({ output = "desc:Dell Inc. DELL U2713HM 7JNY548MA4LS", mode = "preferred", position = "2560x0", scale = 1, transform = 3 })
-- Dell U3223QE on the left of the portrait monitor.
hl.monitor({ output = "desc:Dell Inc. DELL U3223QE F2ZJ4H3", mode = "preferred", position = "0x0", scale = 1 })
