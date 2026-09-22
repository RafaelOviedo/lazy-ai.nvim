# lazy-ai.nvim

Run [LazyAI](https://github.com/RafaelOviedo/lazy-ai) in a floating Neovim terminal.
Toggle back to your code and reopen the same running session.

## Requirements

- Neovim **0.11 or newer**.
- The [LazyAI CLI](https://github.com/RafaelOviedo/lazy-ai#installation) on your
  `PATH` (or an absolute executable path in `cmd`).
- LazyAI requires Node.js 20+ and a locally configured/authenticated Claude Code
  or Codex provider. Follow the CLI's documentation for provider setup.

Install the CLI and verify that it works in your terminal first:

```sh
npm install -g @rafaeloviedo/lazyai
lazyai
```

The plugin uses the CLI's existing authentication and environment.

## Installation

With [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "RafaelOviedo/lazy-ai.nvim",
  cmd = { "LazyAI", "LazyAIOpen", "LazyAIClose", "LazyAIStop", "LazyAIRestart" },
  opts = {},
  keys = {
    {
      "<leader>la",
      function() require("lazy-ai").open() end,
      mode = "n",
      desc = "Open LazyAI",
    },
  },
}
```

No Lua dependencies or `setup()` call are required for the default behavior.
The mapping above is optional; the plugin does not install global keybindings.

## Usage

| Command | Action |
| --- | --- |
| `:LazyAI` | Show/hide the terminal, preserving the running session |
| `:LazyAIOpen` | Open or focus the terminal |
| `:LazyAIClose` | Hide the terminal without stopping the process |
| `:LazyAIStop` | Stop the process and discard its terminal buffer |
| `:LazyAIRestart` | Stop and start again using the current configuration |
| `:checkhealth lazy-ai` | Check Neovim, executable, and working directory |

Lua equivalents are `require("lazy-ai").toggle()`, `open()`, `close()`,
`stop()`, and `restart()`.

There is **one terminal session per Neovim instance**, shared across tabs.
Opening a visible session focuses its window, including switching to its tab.
Closing the float manually also keeps the session alive. Deleting its terminal
buffer stops the process.

The optional `<leader>la` shortcut only works in normal mode and opens or focuses
LazyAI. It never closes the window.

Press `q` on the LazyAI dashboard to quit and close its window. Inside a text
input, `q` remains a normal character. Use `<C-\><C-n>` to enter terminal-normal
mode when you need to run a Neovim command.

A successful process exit closes the float and removes its buffer. A nonzero
exit retains output for inspection and reports the exit code. If the float was
hidden, `:LazyAI` reveals the retained output. Use `:LazyAIRestart` to retry
or `:LazyAIStop` to discard it. Stopping/restarting terminates the CLI; it does
not delete saved provider conversations.

## Configuration

Defaults:

```lua
require("lazy-ai").setup({
  cmd = { "lazyai" },
  -- cwd = nil, -- current Neovim working directory at launch
  win = {
    width = 0.92,
    height = 0.90,
    border = "rounded",
  },
})
```

- `cmd`: a nonempty list containing the executable and any arguments. Arguments
  are passed directly without shell expansion. Paths containing spaces work as
  individual list entries.
- `cwd`: a directory string, or a function returning a directory (or `nil` to
  use Neovim's current working directory). Resolved before the float opens.
- `win.width` / `win.height`: a fraction between 0 and 1, or an integer cell
  count. Sizes are clamped to the editor, and the float recenters on resize.
- `win.border`: `"none"`, `"single"`, `"double"`, `"rounded"`, `"solid"`, or
  `"shadow"`.

For the current buffer's Git project root:

```lua
require("lazy-ai").setup({
  cwd = function()
    return vim.fs.root(0, { ".git" }) or vim.fn.getcwd()
  end,
})
```

A running session keeps its original directory and command when hidden/reopened.
Use `:LazyAIRestart` after switching projects or changing these options.
Each `setup()` call merges its options with defaults and immediately updates
the visible float's appearance.

## Troubleshooting

- **Typing Space + la closes LazyAI:** replace any older terminal-mode toggle
  mapping with the normal-mode `open()` mapping above, then restart Neovim to
  remove the old mapping.

- **Executable not found:** run `:checkhealth lazy-ai`. Neovim may inherit a
  different `PATH` from your shell, especially in a GUI. Set
  `cmd = { "/absolute/path/to/lazyai" }` if needed.
- **No provider available or authentication fails:** run `lazyai` outside
  Neovim and complete the provider setup described in the
  [CLI documentation](https://github.com/RafaelOviedo/lazy-ai#installation).
- **Wrong project:** check `:pwd`, configure `cwd`, then restart the session.
- **Process exited:** inspect the retained terminal output and `:messages`,
  correct the cause, and run `:LazyAIRestart`.

See `:help lazy-ai` for the command and configuration reference.

## Development

Run the regression suite from the repository root:

```sh
nvim --headless -u NONE -i NONE -n -l tests/run.lua
```

Tests use a local shell fixture and do not need LazyAI, credentials, or network
access. Neovim 0.11+ and a POSIX `sh` are required for the tests. CI runs on
Linux and macOS against Neovim 0.11.0 and stable.

## License

[ISC](LICENSE)
