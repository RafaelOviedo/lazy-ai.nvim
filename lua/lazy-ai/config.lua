local M = {}

M.defaults = {
	cmd = { "lazyai" },
	cwd = nil,
	win = {
		width = 0.92,
		height = 0.92,
		border = "rounded",
	},
}

M.options = vim.deepcopy(M.defaults)

local function check(condition, message)
	if not condition then
		error("lazy-ai: " .. message, 3)
	end
end

local function dimension(value, name)
	check(
		type(value) == "number" and value > 0 and value < math.huge and (value < 1 or value == math.floor(value)),
		name .. " must be a fraction between 0 and 1, or a positive integer"
	)
end

function M.setup(opts)
	opts = opts or {}
	check(type(opts) == "table", "options must be a table")
	for key in pairs(opts) do
		check(key == "cmd" or key == "cwd" or key == "win", "unknown option: " .. tostring(key))
	end
	check(opts.win == nil or type(opts.win) == "table", "win must be a table")
	for key in pairs(opts.win or {}) do
		check(key == "width" or key == "height" or key == "border", "unknown win option: " .. tostring(key))
	end

	local options = vim.tbl_deep_extend("force", vim.deepcopy(M.defaults), opts)
	-- Command lists replace defaults rather than merging their arguments.
	if opts.cmd ~= nil then
		options.cmd = vim.deepcopy(opts.cmd)
	end
	check(type(options.cmd) == "table" and vim.islist(options.cmd) and #options.cmd > 0, "cmd must be a nonempty list")
	for index, arg in ipairs(options.cmd) do
		check(type(arg) == "string" and not arg:find("\0", 1, true), "cmd arguments must be strings without NUL bytes")
		check(index ~= 1 or arg ~= "", "cmd executable must not be empty")
	end
	check(
		options.cwd == nil or type(options.cwd) == "string" or type(options.cwd) == "function",
		"cwd must be a path or function"
	)
	dimension(options.win.width, "win.width")
	dimension(options.win.height, "win.height")
	local borders = { none = true, single = true, double = true, rounded = true, solid = true, shadow = true }
	check(
		type(options.win.border) == "string" and borders[options.win.border],
		"win.border must be a built-in border name"
	)
	M.options = options
	return options
end

function M.resolve_cwd()
	local cwd = M.options.cwd
	if type(cwd) == "function" then
		cwd = cwd()
	end
	if cwd == nil then
		cwd = vim.fn.getcwd()
	end
	check(type(cwd) == "string" and cwd ~= "", "cwd must resolve to a nonempty path")
	cwd = vim.fn.fnamemodify(vim.fn.expand(cwd), ":p")
	check(vim.fn.isdirectory(cwd) == 1, "cwd is not a directory: " .. cwd)
	return cwd
end

return M
