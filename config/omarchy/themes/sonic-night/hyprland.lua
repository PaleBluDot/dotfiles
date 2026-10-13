local active_border_color = { colors = { "rgba(2f6bffee)", "rgba(8fb0ffee)" }, angle = 45 }
local active_shadow_color = "rgb(2f6bff)"
local inactive_border_color = "rgba(1c338099)"
local inactive_shadow_color = "rgba(1c338077)"

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
