local active_border_color = { colors = { "rgba(e0262eee)", "rgba(ff9a94ee)" }, angle = 45 }
local active_shadow_color = "rgb(e0262e)"
local inactive_border_color = "rgba(5c141899)"
local inactive_shadow_color = "rgba(5c141877)"

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
