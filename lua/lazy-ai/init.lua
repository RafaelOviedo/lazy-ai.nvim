local config = require("lazy-ai.config")
local M = {}
local session
local group = vim.api.nvim_create_augroup("LazyAI", { clear = true })

local function notify(message)
	vim.notify("LazyAI: " .. message, vim.log.levels.ERROR)
end

local function valid_buffer(s)
	return s and vim.api.nvim_buf_is_valid(s.buf) and vim.api.nvim_buf_is_loaded(s.buf)
end

local function visible(s)
	return s
		and s.win
		and vim.api.nvim_win_is_valid(s.win)
		and vim.api.nvim_win_get_buf(s.win) == s.buf
end

local function window_config()
	local opts = config.options.win
	local border = opts.border
	-- Reserve space for the border, command line, and tab line even on tiny UIs.
	local columns = math.max(1, vim.o.columns)
	local lines = math.max(1, vim.o.lines - vim.o.cmdheight - (vim.o.showtabline == 0 and 0 or 1))
	if columns < 3 or lines < 3 then
		border = "none"
	end
	local padding = border == "none" and 0 or 2
	local function size(value, available)
		return math.max(1, math.min(math.floor(value < 1 and available * value or value), available - padding))
	end
	local width, height = size(opts.width, columns), size(opts.height, lines)
	return {
		relative = "editor",
		width = width,
		height = height,
		row = math.max(0, math.floor((lines - height - padding) / 2)),
		col = math.max(0, math.floor((columns - width - padding) / 2)),
		style = "minimal",
		border = border,
	}
end

local function stop_job(s)
	local job = s.job
	s.job = nil
	if job then
		pcall(vim.fn.jobstop, job)
	end
end

local function dispose(s)
	-- Invalidate ownership before triggering window, buffer, or job callbacks.
	if session == s then
		session = nil
	end
	stop_job(s)
	if visible(s) then
		pcall(vim.api.nvim_win_close, s.win, true)
	end
	if vim.api.nvim_buf_is_valid(s.buf) then
		pcall(vim.api.nvim_buf_delete, s.buf, { force = true })
	end
end

local function focus(s)
	if visible(s) then
		vim.api.nvim_set_current_win(s.win)
	else
		s.origin = vim.api.nvim_get_current_win()
		s.win = vim.api.nvim_open_win(s.buf, true, window_config())
	end
	if s.job then
		vim.cmd("startinsert")
	else
		vim.cmd("stopinsert")
	end
end

function M.open()
	if vim.fn.has("nvim-0.11") ~= 1 then
		notify("Neovim 0.11 or newer is required.")
		return
	end

	if valid_buffer(session) then
		local ok, err = pcall(focus, session)
		if not ok then
			notify("Could not open terminal: " .. tostring(err))
		end
		return
	elseif session then
		dispose(session)
	end

	local cmd = config.options.cmd
	if vim.fn.executable(cmd[1]) ~= 1 then
		notify("Executable not found: " .. cmd[1] .. ". Install LazyAI or set setup({ cmd = { '/path/to/lazyai' } }).")
		return
	end

	-- Resolve before entering the float so a resolver sees the caller's buffer.
	local ok, cwd = pcall(config.resolve_cwd)
	if not ok then
		notify(tostring(cwd))
		return
	end

	local s = { buf = vim.api.nvim_create_buf(false, true), cwd = cwd }
	session = s
	vim.bo[s.buf].bufhidden = "hide"
	vim.api.nvim_create_autocmd({ "BufUnload", "BufWipeout" }, {
		group = group,
		buffer = s.buf,
		callback = function()
			if session == s then
				session = nil
				stop_job(s)
				vim.schedule(function()
					dispose(s)
				end)
			end
		end,
	})

	local opened, err = pcall(focus, s)
	if not opened then
		dispose(s)
		notify("Could not open terminal: " .. tostring(err))
		return
	end

	local started, job = pcall(vim.fn.jobstart, vim.deepcopy(cmd), {
		term = true,
		cwd = cwd,
		on_exit = function(_, code)
			vim.schedule(function()
				-- An old process must never alter a replacement session.
				if session ~= s then
					return
				end
				s.job = nil
				s.exit_code = code
				if code == 0 then
					dispose(s)
				else
					if visible(s) and vim.api.nvim_get_current_win() == s.win then
						vim.cmd("stopinsert")
					end
					notify("Process exited with code " .. code .. ". Output retained; use :LazyAIRestart to retry.")
				end
			end)
		end,
	})
	if not started or type(job) ~= "number" or job <= 0 then
		dispose(s)
		notify("Could not start " .. cmd[1] .. ": " .. tostring(job))
		return
	end
	s.job = job
	vim.bo[s.buf].filetype = "lazyai"
	vim.bo[s.buf].bufhidden = "hide"
	vim.cmd("startinsert")
end

-- Closing hides the terminal; the job and its working directory are retained.
function M.close()
	local s = session
	if not visible(s) then
		return
	end
	local focused = vim.api.nvim_get_current_win() == s.win
	vim.api.nvim_win_close(s.win, true)
	s.win = nil
	if focused then
		vim.cmd("stopinsert")
		if s.origin and vim.api.nvim_win_is_valid(s.origin) then
			vim.api.nvim_set_current_win(s.origin)
		end
	end
end

function M.toggle()
	if visible(session) then
		M.close()
	else
		M.open()
	end
end

function M.stop()
	if session then
		dispose(session)
	end
end

function M.restart()
	M.stop()
	M.open()
end

function M.setup(opts)
	config.setup(opts)
	if visible(session) then
		vim.api.nvim_win_set_config(session.win, window_config())
	end
end

vim.api.nvim_create_autocmd("WinClosed", {
	group = group,
	callback = function(event)
		if session and session.win == tonumber(event.match) then
			session.win = nil
		end
	end,
})

vim.api.nvim_create_autocmd("VimResized", {
	group = group,
	callback = function()
		if visible(session) then
			vim.api.nvim_win_set_config(session.win, window_config())
		end
	end,
})

vim.api.nvim_create_autocmd("VimLeavePre", {
	group = group,
	callback = M.stop,
})

return M
