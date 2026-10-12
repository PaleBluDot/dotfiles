local active_border_color = { colors = { "rgba(ff9f1cee)", "rgba(ffd99aee)" }, angle = 45 }
local active_shadow_color = "rgb(ff9f1c)"
local inactive_border_color = "rgba(5c3a1099)"
local inactive_shadow_color = "rgba(5c3a1077)"

hl.config({
  general = {
    col = {
      active_border = active_border_color,
      inactive_border = inactive_border_color,
    }
  },

  group = {
    col = {
      border_active = active_border_color,
      border_inactive = inactive_border_color,
    },
  },

  decoration = {
    shadow = {
      enabled = true,
      range = 6,
      render_power = 4,
      color = active_shadow_color,
      color_inactive = inactive_shadow_color,
    },
  },
})
