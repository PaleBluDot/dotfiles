return {
	-- Tell LazyVim which colorscheme to load
	{
		"LazyVim/LazyVim",
		opts = {
			colorscheme = "catppuccin",
		},
	},

	-- Configure Catppuccin
	{
		"catppuccin/nvim",
		name = "catppuccin",
		opts = {
			flavour = "mocha",

			transparent_background = true,
			float = {
				transparent = true,
				solid = false,
			},

			term_colors = true,

			dim_inactive = {
				enabled = false,
				shade = "dark",
				percentage = 0.15,
			},

			no_italic = false,
			no_bold = false,
			no_underline = false,

			styles = {
				comments = { "italic" },
				conditionals = { "italic" },
				loops = {},
				functions = {},
				keywords = {},
				strings = {},
				variables = {},
				numbers = {},
				booleans = {},
				properties = {},
				types = {},
				operators = {},
			},

			lsp_styles = {
				virtual_text = {
					errors = { "italic" },
					hints = { "italic" },
					warnings = { "italic" },
					information = { "italic" },
					ok = { "italic" },
				},
				underlines = {
					errors = { "underline" },
					hints = { "underline" },
					warnings = { "underline" },
					information = { "underline" },
					ok = { "underline" },
				},
				inlay_hints = {
					background = true,
				},
			},

			auto_integrations = true,
		},
	},
}
