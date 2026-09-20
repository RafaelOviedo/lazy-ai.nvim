if vim.g.loaded_lazy_ai then
	return
end
vim.g.loaded_lazy_ai = true

local commands = {
	LazyAI = { "toggle", "Toggle the LazyAI terminal" },
	LazyAIOpen = { "open", "Open or focus the LazyAI terminal" },
	LazyAIClose = { "close", "Hide LazyAI without stopping its session" },
	LazyAIStop = { "stop", "Stop LazyAI and discard its terminal buffer" },
	LazyAIRestart = { "restart", "Restart LazyAI using the current configuration" },
}
for name, command in pairs(commands) do
	local action = command[1]
	vim.api.nvim_create_user_command(name, function()
		require("lazy-ai")[action]()
	end, { desc = command[2] })
end
