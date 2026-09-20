local M = {}

function M.check()
	vim.health.start("lazy-ai.nvim")
	if vim.fn.has("nvim-0.11") == 1 then
		vim.health.ok("Neovim 0.11+")
	else
		vim.health.error("Neovim 0.11 or newer is required")
	end

	local config = require("lazy-ai.config")
	local executable = config.options.cmd[1]
	if vim.fn.executable(executable) == 1 then
		vim.health.ok("Executable: " .. vim.fn.exepath(executable))
	else
		vim.health.error("Executable not found: " .. executable, {
			"Install LazyAI with npm install -g @rafaeloviedo/lazyai",
			"Or configure cmd = { '/absolute/path/to/lazyai' }",
		})
	end

	local ok, cwd = pcall(config.resolve_cwd)
	if ok then
		vim.health.ok("Working directory: " .. cwd)
	else
		vim.health.error(tostring(cwd))
	end
	vim.health.info("Run LazyAI in a terminal first to verify provider setup and authentication.")
end

return M
