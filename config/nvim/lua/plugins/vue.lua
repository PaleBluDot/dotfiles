-- Vue support, used instead of LazyVim's lang.vue extra.
-- That extra only works when vtsls is the TypeScript server, and here tsc is
-- (vim.g.lazyvim_ts_lsp in options.lua). tsc can't load the Vue TypeScript
-- plugin, so vtsls runs too, but only for .vue files.
return {
	{
		"nvim-treesitter/nvim-treesitter",
		opts = { ensure_installed = { "vue", "css" } },
	},
	{
		"neovim/nvim-lspconfig",
		opts = function(_, opts)
			opts.servers.vue_ls = opts.servers.vue_ls or {}
			-- the typescript extra turns vtsls off because tsc is picked; turn it back on for .vue only
			opts.servers.vtsls = vim.tbl_deep_extend("force", opts.servers.vtsls or {}, {
				enabled = true,
				filetypes = { "vue" },
				settings = {
					vtsls = {
						tsserver = {
							globalPlugins = {
								{
									name = "@vue/typescript-plugin",
									location = LazyVim.get_pkg_path("vue-language-server", "/node_modules/@vue/language-server"),
									languages = { "vue" },
									configNamespace = "typescript",
									enableForWorkspaceTypeScriptVersions = true,
								},
							},
						},
					},
				},
			})
		end,
	},
}
