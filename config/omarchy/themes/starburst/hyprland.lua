local active_border_color = { colors = { "rgba(eb5a47ee)", "rgba(d9df34ee)" }, angle = 45 }
local active_shadow_color = "rgb(eb5a47)"
local inactive_border_color = "rgba(41414199)"
local inactive_shadow_color = "rgba(41414177)"

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
