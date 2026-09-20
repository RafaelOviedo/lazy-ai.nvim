vim.opt.runtimepath:prepend(vim.fn.getcwd())
vim.o.swapfile = false
vim.o.hidden = true
vim.o.columns = 100
vim.o.lines = 40
vim.cmd("runtime plugin/lazy-ai.lua")

local plugin = require("lazy-ai")
local config = require("lazy-ai.config")
local root = vim.fn.getcwd()
local fixture = root .. "/tests/fixtures/terminal.sh"
local command = { "sh", fixture, "argument with spaces" }
local original = {
	jobstart = vim.fn.jobstart,
	executable = vim.fn.executable,
	has = vim.fn.has,
	notify = vim.notify,
	open_win = vim.api.nvim_open_win,
}
local notices = {}
vim.notify = function(message)
	notices[#notices + 1] = message
end

local function equal(actual, expected)
	assert(vim.deep_equal(actual, expected), "expected " .. vim.inspect(expected) .. ", got " .. vim.inspect(actual))
end

local function wait_for(predicate)
	assert(vim.wait(3000, predicate, 10), "timed out waiting for terminal state")
end

local function output(buf)
	return table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
end

local function launch()
	plugin.open()
	local buf, win = vim.api.nvim_get_current_buf(), vim.api.nvim_get_current_win()
	assert(vim.bo[buf].buftype == "terminal", "expected a terminal buffer")
	wait_for(function()
		return output(buf):find("fixture ready", 1, true) ~= nil
	end)
	return buf, win, vim.bo[buf].channel
end

local function running(job)
	return vim.fn.jobwait({ job }, 0)[1] == -1
end

local function buffer_count()
	return #vim.api.nvim_list_bufs()
end

local failures, passed = {}, 0
local function test(name, fn)
	plugin.stop()
	vim.wait(20)
	vim.fn.chdir(root)
	plugin.setup({ cmd = command })
	notices = {}
	local ok, err = xpcall(fn, debug.traceback)
	vim.fn.jobstart = original.jobstart
	vim.fn.executable = original.executable
	vim.fn.has = original.has
	vim.api.nvim_open_win = original.open_win
	plugin.stop()
	vim.wait(20)
	if ok then
		passed = passed + 1
		print("PASS " .. name)
	else
		failures[#failures + 1] = name .. "\n" .. err
		print("FAIL " .. name .. "\n" .. err)
	end
end

test("defaults work without setup and command loading is idempotent", function()
	package.loaded["lazy-ai.config"] = nil
	local defaults = require("lazy-ai.config")
	equal(defaults.options.cmd, { "lazyai" })
	equal(defaults.options.win.border, "rounded")
	package.loaded["lazy-ai.config"] = config
	dofile("plugin/lazy-ai.lua")
	for _, name in ipairs({ "LazyAI", "LazyAIOpen", "LazyAIClose", "LazyAIStop", "LazyAIRestart" }) do
		equal(vim.fn.exists(":" .. name), 2)
	end
end)

test("invalid setup is rejected without changing existing options", function()
	local previous = vim.deepcopy(config.options)
	for _, opts in ipairs({
		{ cmd = {} },
		{ cmd = "lazyai" },
		{ cmd = { "" } },
		{ cmd = { "sh", 1 } },
		{ cwd = false },
		{ win = false },
		{ win = { width = 0 } },
		{ win = { height = -1 } },
		{ win = { width = 1.5 } },
		{ win = { height = math.huge } },
		{ win = { border = "unknown" } },
		{ unknown = true },
	}) do
		equal(pcall(plugin.setup, opts), false)
		equal(config.options, previous)
	end
end)

test("toggle preserves buffer, job, output, and arguments", function()
	local origin = vim.api.nvim_get_current_win()
	local buf, _, job = launch()
	assert(output(buf):find("arg=argument with spaces", 1, true))
	for _ = 1, 3 do
		plugin.toggle()
		equal(vim.api.nvim_get_current_win(), origin)
		assert(running(job))
		plugin.toggle()
		equal(vim.api.nvim_get_current_buf(), buf)
		equal(vim.bo[buf].channel, job)
	end
	vim.fn.chansend(job, "hello\n")
	wait_for(function()
		return output(buf):find("received=hello", 1, true) ~= nil
	end)
end)

test("manual window closure preserves the session", function()
	local buf, win, job = launch()
	vim.api.nvim_win_close(win, true)
	plugin.open()
	equal(vim.api.nvim_get_current_buf(), buf)
	assert(running(job))
end)

test("opening from another tab focuses the existing session", function()
	local buf, win = launch()
	vim.cmd("tabnew")
	local other = vim.api.nvim_get_current_tabpage()
	plugin.open()
	equal(vim.api.nvim_get_current_win(), win)
	equal(vim.api.nvim_get_current_buf(), buf)
	plugin.close()
	vim.api.nvim_set_current_tabpage(other)
	vim.cmd("tabclose")
end)

test("buffer wipe stops the job and cannot destroy a replacement", function()
	local buf, _, job = launch()
	vim.api.nvim_buf_delete(buf, { force = true })
	local replacement = launch()
	assert(replacement ~= buf)
	wait_for(function()
		return not running(job)
	end)
	assert(vim.api.nvim_buf_is_valid(replacement))
	equal(vim.api.nvim_get_current_buf(), replacement)
end)

test("buffer unload stops the job and permits a fresh session", function()
	local buf, _, job = launch()
	vim.api.nvim_buf_delete(buf, { force = true, unload = true })
	wait_for(function()
		return not running(job)
	end)
	local replacement = launch()
	assert(replacement ~= buf)
end)

test("stale exit callback cannot close a restarted session", function()
	local callbacks = {}
	vim.fn.jobstart = function(cmd, opts)
		callbacks[#callbacks + 1] = opts.on_exit
		return original.jobstart(cmd, opts)
	end
	local buf, _, oldjob = launch()
	plugin.restart()
	local newbuf, newwin, newjob = launch()
	assert(newbuf ~= buf and newjob ~= oldjob)
	callbacks[1](oldjob, 0)
	callbacks[1](oldjob, 7)
	vim.wait(50)
	assert(vim.api.nvim_win_is_valid(newwin))
	assert(vim.api.nvim_buf_is_valid(newbuf))
	assert(running(newjob))
	equal(#notices, 0)
end)

test("successful exit removes the window and buffer", function()
	local buf, win, job = launch()
	vim.fn.chansend(job, "exit\n")
	wait_for(function()
		return not vim.api.nvim_buf_is_valid(buf)
	end)
	assert(not vim.api.nvim_win_is_valid(win))
	equal(#notices, 0)
end)

test("failed exit retains output, including while hidden", function()
	local buf, _, job = launch()
	plugin.close()
	vim.fn.chansend(job, "fail\n")
	wait_for(function()
		return #notices > 0
	end)
	assert(notices[1]:find("code 7", 1, true))
	plugin.open()
	equal(vim.api.nvim_get_current_buf(), buf)
	assert(output(buf):find("fixture failure", 1, true))
	plugin.close()
	plugin.open()
	equal(vim.api.nvim_get_current_buf(), buf)
	plugin.restart()
	local replacement = launch()
	assert(replacement ~= buf)
end)

test("stop removes a hidden session and terminates its job", function()
	local buf, _, job = launch()
	plugin.close()
	plugin.stop()
	plugin.stop()
	wait_for(function()
		return not running(job)
	end)
	assert(not vim.api.nvim_buf_is_valid(buf))
end)

test("missing executable does not create a buffer", function()
	plugin.setup({ cmd = { "lazy-ai-nonexistent-test-command" } })
	local before = buffer_count()
	plugin.open()
	equal(buffer_count(), before)
	assert(notices[1]:find("Executable not found", 1, true))
end)

test("failed jobstart return values and exceptions clean up", function()
	for _, result in ipairs({ 0, -1, "exception" }) do
		vim.fn.jobstart = function()
			if result == "exception" then
				error("simulated spawn failure")
			end
			return result
		end
		local before, windows = buffer_count(), #vim.api.nvim_list_wins()
		plugin.open()
		equal(buffer_count(), before)
		equal(#vim.api.nvim_list_wins(), windows)
		assert(notices[#notices]:find("Could not start", 1, true))
	end
end)

test("failed window creation cleans up", function()
	local before = buffer_count()
	vim.api.nvim_open_win = function()
		error("simulated window failure")
	end
	plugin.open()
	equal(buffer_count(), before)
	assert(notices[1]:find("Could not open terminal", 1, true))
end)

test("invalid or throwing cwd resolver fails before allocating a buffer", function()
	for _, cwd in ipairs({
		root .. "/does-not-exist",
		function() error("resolver failed") end,
		function() return false end,
	}) do
		plugin.setup({ cmd = command, cwd = cwd })
		local before = buffer_count()
		plugin.open()
		equal(buffer_count(), before)
	end
	equal(#notices, 3)
end)

test("cwd resolver sees caller and is only rerun for a new session", function()
	local caller, calls = vim.api.nvim_get_current_buf(), 0
	plugin.setup({
		cmd = command,
		cwd = function()
			equal(vim.api.nvim_get_current_buf(), caller)
			calls = calls + 1
			return root
		end,
	})
	local buf = launch()
	assert(output(buf):find("cwd=" .. root, 1, true))
	plugin.close()
	vim.fn.chdir(root .. "/tests")
	plugin.open()
	equal(vim.api.nvim_get_current_buf(), buf)
	equal(calls, 1)
	plugin.close()
	plugin.restart()
	launch()
	equal(calls, 2)
end)

test("default cwd follows launch directory but not subsequent toggles", function()
	vim.fn.chdir(root .. "/tests")
	local buf = launch()
	assert(output(buf):find("cwd=" .. root .. "/tests", 1, true))
	plugin.close()
	vim.fn.chdir(root)
	plugin.open()
	equal(vim.api.nvim_get_current_buf(), buf)
	plugin.restart()
	local fresh = launch()
	local text = output(fresh)
	assert(text:find("cwd=" .. root, 1, true))
	assert(not text:find("cwd=" .. root .. "/tests", 1, true))
end)

test("resize clamps and recenters the existing window", function()
	local _, win = launch()
	local before = vim.api.nvim_win_get_config(win)
	vim.o.columns = 32
	vim.o.lines = 12
	vim.api.nvim_exec_autocmds("VimResized", {})
	local after = vim.api.nvim_win_get_config(win)
	assert(after.width < before.width and after.height < before.height)
	assert(after.width > 0 and after.height > 0)
	assert(after.width + 2 <= vim.o.columns)
	assert(after.height + 2 <= vim.o.lines)
	assert(after.row >= 0 and after.col >= 0)
	plugin.setup({ cmd = command, win = { width = 500, height = 500 } })
	after = vim.api.nvim_win_get_config(win)
	assert(after.width + 2 <= vim.o.columns)
	assert(after.height + 2 <= vim.o.lines)
	plugin.setup({ cmd = command, win = { width = 1, height = 1, border = "none" } })
	after = vim.api.nvim_win_get_config(win)
	equal(after.width, 1)
	equal(after.height, 1)
	vim.o.columns = 100
	vim.o.lines = 40
end)

test("unsupported Neovim version is reported before launch", function()
	vim.fn.has = function(feature)
		return feature == "nvim-0.11" and 0 or original.has(feature)
	end
	local before = buffer_count()
	plugin.open()
	equal(buffer_count(), before)
	assert(notices[1]:find("0.11", 1, true))
end)

test("health checks report executable and cwd failures without launching", function()
	local report = {}
	local health = vim.health
	vim.health = {
		start = function() end,
		ok = function(message) report[#report + 1] = "ok:" .. message end,
		error = function(message) report[#report + 1] = "error:" .. message end,
		info = function() end,
	}
	local ok, err = pcall(function()
		require("lazy-ai.health").check()
		equal(#report, 3)
		assert(report[2]:find("ok:Executable", 1, true))
		report = {}
		plugin.setup({ cmd = { "lazy-ai-nonexistent-test-command" }, cwd = root .. "/does-not-exist" })
		require("lazy-ai.health").check()
		assert(report[2]:find("error:Executable", 1, true))
		assert(report[3]:find("error:", 1, true))
	end)
	vim.health = health
	assert(ok, err)
end)

plugin.stop()
vim.notify = original.notify
vim.fn.chdir(root)
print(string.format("\n%d passed, %d failed", passed, #failures))
if #failures > 0 then
	vim.cmd("cquit 1")
else
	vim.cmd("qa!")
end
