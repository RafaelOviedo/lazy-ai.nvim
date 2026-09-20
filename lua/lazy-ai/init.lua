local M = {}

local state = {
	buf = nil,
	win = nil,
}

local function is_open()
	return state.win and vim.api.nvim_win_is_valid(state.win)
end

function M.open()
	if vim.fn.executable("lazyai") ~= 1 then
		vim.notify("LazyAI executable not found", vim.log.levels.ERROR)
		return
	end

	if is_open() then
		vim.api.nvim_set_current_win(state.win)
		return
	end

	local width = math.floor(vim.o.columns * 0.92)
	local height = math.floor(vim.o.lines * 0.90)
	local row = math.floor((vim.o.lines - height) / 2)
	local col = math.floor((vim.o.columns - width) / 2)

	state.buf = vim.api.nvim_create_buf(false, true)

	state.win = vim.api.nvim_open_win(state.buf, true, {
		relative = "editor",
		width = width,
		height = height,
		row = row,
		col = col,
		style = "minimal",
		border = "rounded",
	})

	vim.fn.jobstart({ "lazyai" }, {
		term = true,
		cwd = vim.fn.getcwd(),

		on_exit = function()
			vim.schedule(function()
				if is_open() then
					vim.api.nvim_win_close(state.win, true)
				end

				state.win = nil
				state.buf = nil
			end)
		end,
	})

	vim.cmd("startinsert")
end

function M.close()
	if is_open() then
		vim.api.nvim_win_close(state.win, true)
	end

	state.win = nil
	state.buf = nil
end

function M.toggle()
	if is_open() then
		M.close()
	else
		M.open()
	end
end

function M.setup(opts)
	-- configuration later
end

return M
