# nvim-dap-lldb

An extension for [nvim-dap](https://github.com/mfussenegger/nvim-dap) to provide C, C++, and Rust debugging support.

### Requirements

- [nvim-dap](https://github.com/mfussenegger/nvim-dap) plugin.
- [CodeLLDB](https://github.com/vadimcn/codelldb) debugger extension.

### Installation

Just like any other NeoVim plugin.

Here is an example using [Lazy](https://github.com/folke/lazy.nvim) package manager:

```lua
{
   "julianolf/nvim-dap-lldb",
   dependencies = { "mfussenegger/nvim-dap" },
   opts = { codelldb_path = "/path/to/codelldb" },
}
```

For CodeLLDB installation, I recommend using [mason.vim](https://github.com/williamboman/mason.nvim). When using Mason, you can omit the `codelldb_path` option, the plugin will figure it out where it's been installed. If no path is given and Mason is not available, the plugin will assume that CodeLLDB is on the system path.

### Languages support

Technically LLDB supports a broad number of programming languages as its foundation leverages on libraries coming from the LLVM project.

To use it with programming languages that do not have default configurations provided, you have to add custom launch configurations.

### Custom configurations

You can pass custom configurations in two different ways: by passing a Lua table when setting up the plugin or loading a JSON file.

1. Custom launch configuration in Lua:

```lua
local cfg = {
   configurations = {
      -- C lang configurations
      c = {
         {
            name = "Launch debugger",
            type = "lldb",
            request = "launch",
            cwd = "${workspaceFolder}",
            program = function()
               -- Build with debug symbols
               local out = vim.fn.system({"make", "debug"})
               -- Check for errors
               if vim.v.shell_error ~= 0 then
                  vim.notify(out, vim.log.levels.ERROR)
                  return nil
               end
               -- Return path to the debuggable program
               return "path/to/executable"
            end,
         },
      },
   },
}

require("dap-lldb").setup(cfg)
```

2. JSON configuration file:

```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "Launch debugger",
      "type": "lldb",
      "request": "launch",
      "cwd": "${workspaceFolder}",
      "program": "path/to/executable"
    }
  ]
}
```

_Assuming the above JSON was saved in .vscode/launch.json._

When starting a debug session via `dap.continue()` the JSON file is automatically loaded. It's also possible to manually load the file using the `load_launchjs` function.

For more details on how to load launch configuration files, refer to the docs:
- `:help dap-launch.json`
- `:help dap-providers-configs`

This is useful when collaborating with programmers who use [Visual Studio Code](https://code.visualstudio.com/), allowing reuse of the same configurations.

For a complete reference on how to create your own configurations, refer to the CodeLLDB user's [manual](https://github.com/vadimcn/codelldb/blob/master/MANUAL.md).

### Usage

- `:lua require('dap').continue()` to start debugging.
- `:lua require('dap-lldb').debug_test()` to debug the test function above the cursor (Rust-only feature).
- `:help dap-api` for more detailed information on how to work with DAP.
