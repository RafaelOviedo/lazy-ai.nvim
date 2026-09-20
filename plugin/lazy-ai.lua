if vim.g.loaded_lazy_ai then
	return
end

vim.g.loaded_lazy_ai = true

vim.api.nvim_create_user_command("LazyAI", function()
	require("lazy-ai").toggle()
end, {
	desc = "Toggle LazyAI",
})
