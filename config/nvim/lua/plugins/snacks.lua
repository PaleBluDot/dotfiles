return {
	"folke/snacks.nvim",
	opts = {
		-- Turn on the modules most people use
		bigfile = { enabled = true }, -- stops huge files from freezing Neovim
		dashboard = { enabled = true }, -- the start screen
		explorer = { enabled = true }, -- file tree sidebar
		indent = { enabled = true }, -- indent guide lines
		input = { enabled = true }, -- nicer input prompts
		notifier = {
			enabled = true, -- pop-up notifications
			timeout = 3000, -- ms before a notification disappears
		},
		picker = {
			enabled = true, -- fuzzy finder: files, grep, buffers
			sources = {
				-- FROM MEMORY, NOT VERIFIED: show dotfiles in these two
				files = { hidden = true },
				explorer = { hidden = true },
			},
		},
		quickfile = { enabled = true }, -- faster load when opening a file directly
		scope = { enabled = true }, -- scope detection for the current code block
		scroll = { enabled = true }, -- smooth scrolling
		statuscolumn = { enabled = true }, -- the strip left of the line numbers
		words = { enabled = true }, -- highlights other uses of the word under the cursor

		styles = {
			notification = {
				wo = { wrap = true }, -- wrap long notification text
			},
		},
	},
}
