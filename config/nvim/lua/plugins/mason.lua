return {
	"mason-org/mason.nvim",
	-- :checkhealth mason always checks for these languages and warns when they're missing.
	-- I don't use them, and mason has no setting to skip them, so drop just those warnings.
	init = function()
		local unused = { cargo = true, javac = true, java = true, julia = true }
		local warn = vim.health.warn
		vim.health.warn = function(msg, ...)
			local name = type(msg) == "string" and msg:match("^(%w+): not available$")
			if name and unused[name] then
				return
			end
			return warn(msg, ...)
		end
	end,
}
