# shroud.nvim

`shroud.nvim` is a basic Neovim plugin that provides a way to selectively hide or "shroud" parts of text using virtual overlays. It's useful for hiding sensitive information, such as passwords or API keys, while still keeping the text in the buffer.

---

## Features

- Patten-based text hiding using Lua [patterns](https://www.lua.org/manual/5.1/manual.html#5.4.1).
- Configurable overlay characters applied non-destructively.
- Customisable offset handling for different matching patterns.
- Peek functionality to temporarily reveal hidden text.

---

## Installation

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "chriso345/shroud.nvim",
  opts = {
    enabled = true,          -- Enable shrouding by default
    patterns = {
      { file = "*.env*", shroud = "=.*" } -- Shroud everything after '=' in .env files
    },
    character = "*",         -- Character used to shroud text
    offset = 1,              -- Set to 1 to include the prefix character in the shrouded text
    on_shroud = function()   -- Runs on shrouding text, useful for disabling completion
      require('cmp').setup.buffer({ enabled = false })
    end,
    on_unshroud = function() -- Runs on unshrouding text, usefule for re-enabling completion
      require('cmp').setup.buffer({ enabled = true })
    end,
  }
}
```

---

## Usage

`shroud.nvim` provides several commands to manage shrouding in your Neovim buffers. You can enable, disable, toggle, or peek at shrouded text.

| Command          | Description                                              |
| ---------------- | -------------------------------------------------------- |
| `:ShroudEnable`  | Enables shrouding based on your settings                 |
| `:ShroudDisable` | Disables all shrouds                                     |
| `:ShroudToggle`  | Toggles shrouding on/off                                 |
| `:ShroudPeek`    | Temporarily reveals hidden text                          |

These are ideal for use in keymaps or command-line workflows.

```lua
vim.keymap.set("n", "<leader>se", "<cmd>ShroudEnable<CR>")
vim.keymap.set("n", "<leader>sd", "<cmd>ShroudDisable<CR>")
vim.keymap.set("n", "<leader>st", "<cmd>ShroudToggle<CR>")
vim.keymap.set("n", "<leader>sp", "<cmd>ShroudPeek<CR>")
```

---

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for more details.
