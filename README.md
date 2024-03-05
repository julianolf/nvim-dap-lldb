# nvim-dap-lldb

An extension for [nvim-dap](https://github.com/mfussenegger/nvim-dap) to provide C, C++ and Rust debugging support.

### Requires

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

For CodeLLDB installation I recommend using [mason.vim](https://github.com/williamboman/mason.nvim). When using Mason you can omit the `codelldb_path` option, the plugin will figure it out where it's been installed. If no path is given and Mason is not available the plugin will assume that CodeLLDB is on the system path.

### Custom configurations

You can pass custom configurations in two different ways, by passing a Lua table when setting up the plugin or pointing to a JSON file.

1. Custom launch configuration in Lua:

```lua
local cfg = {
   configurations = {
      c = { -- c lang configurations
         {
            name = "Launch debugger",
            type = "lldb",
            request = "launch",
            cwd = "${workspaceFolder}",
            program = function()
                    local out = vim.fn.system({"make", "debug"}) -- build with debug symbols
                    if vim.v.shell_error ~= 0 then -- check for errors
                       vim.notify(out, vim.log.levels.ERROR)
                       return nil
                    return "path/to/executable" -- return path to the debuggable program
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

```lua
local cfg = { launch_file = ".vscode/launch.json" }

require("dap-lldb").setup(cfg)
```
This is useful when collaborating with programmers who use [Visual Studio Code](https://code.visualstudio.com/) allowing to reuse the same configurations.

For a complete reference on how to create your own configurations head to CodeLLDB user's [manual](https://github.com/vadimcn/codelldb/blob/master/MANUAL.md).

#### Extending configurations

When passing custom configurations to the plugin its default behavior is to override the predefined configurations, if you want to keep them and add some more set the configuration flag `extend_config`.

```lua
local cfg = {
   extend_config = true,
   launch_file = ".vscode/launch.json",
}

require("dap-lldb").setup(cfg)
```
