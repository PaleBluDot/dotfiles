-- Show markdown as plain text. LazyVim's lang.markdown extra adds
-- render-markdown.nvim, which hides backticks and code fences but leaves
-- # headings visible. The extra's linting and marksman keep working.
return {
	{ "MeanderingProgrammer/render-markdown.nvim", enabled = false },
}
