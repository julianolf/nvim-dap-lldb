# nvim-dap-lldb

An extension for [nvim-dap](https://github.com/mfussenegger/nvim-dap) to provide C, C++ and Rust debugging support.

## Requires

- [nvim-dap](https://github.com/mfussenegger/nvim-dap) plugin.
- [CodeLLDB](https://github.com/vadimcn/codelldb) debugger extension.

## Installation

Just like any other NeoVim plugin.

Here is an example using [Lazy](https://github.com/folke/lazy.nvim):
```lua
{
   "julianolf/nvim-dap-lldb",
   dependencies = { "mfussenegger/nvim-dap" },
   opts = { codelldb_path = "/path/to/codelldb" },
}
```

For CodeLLDB installation I recommend using [mason.vim](https://github.com/williamboman/mason.nvim). When using Mason you can omit the `codelldb_path` option, the extension will find it automatically.
