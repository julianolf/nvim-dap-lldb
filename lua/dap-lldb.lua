local M = {}

local function require_dap()
   local ok, dap = pcall(require, "dap")
   assert(ok, "nvim-dap is required to use dap-lldb")
   return dap
end

local function find_codelldb()
   local ok, registry = pcall(require, "mason-registry")

   if ok and registry.is_installed("codelldb") then
      local pkg = registry.get_package("codelldb")
      local sep = package.config:sub(1, 1)
      return table.concat({ pkg:get_install_path(), "extension", "adapter", "codelldb" }, sep)
   end

   return nil
end

local function list_targets()
   local targets = {}
   local command = { "cargo", "build", "--quiet", "--message-format", "json" }
   local outputs = vim.fn.systemlist(command)

   if vim.v.shell_error ~= 0 then
      vim.notify("cargo build failed", vim.log.levels.ERROR)
      return targets
   end

   for _, line in ipairs(outputs) do
      local json = vim.fn.json_decode(line)

      if
         type(json) == "table"
         and json.reason == "compiler-artifact"
         and json.executable ~= nil
         and vim.tbl_contains(json.target.kind, "bin")
      then
         table.insert(targets, json.executable)
      end
   end

   return targets
end

local function select_target()
   local targets = list_targets()
   local sep = package.config:sub(1, 1)

   if #targets == 0 then
      return vim.fn.input("Path to executable: ", vim.fn.getcwd() .. sep, "file")
   end

   if #targets == 1 then
      return targets[1]
   end

   local options = { "Select a target:" }

   for index, target in ipairs(targets) do
      local parts = vim.split(target, sep, { trimempty = true })
      local option = index .. ". " .. parts[#parts]
      table.insert(options, option)
   end

   local choice = vim.fn.inputlist(options)

   return targets[choice]
end

local function read_args()
   local args = vim.fn.input("Enter args: ")
   return vim.split(args, " ", { trimempty = true })
end

function M.setup(opts)
   local dap = require_dap()
   local codelldb = opts.codelldb_path or find_codelldb() or "codelldb"

   dap.adapters.codelldb = {
      type = "server",
      port = "${port}",
      executable = {
         command = codelldb,
         args = { "--port", "${port}" },
         detached = vim.loop.os_uname().sysname ~= "Windows",
      },
   }

   dap.configurations.rust = {
      {
         name = "Debug",
         type = "codelldb",
         request = "launch",
         cwd = "${workspaceFolder}",
         program = select_target,
         stopOnEntry = false,
      },
      {
         name = "Debug w/ args",
         type = "codelldb",
         request = "launch",
         cwd = "${workspaceFolder}",
         program = select_target,
         args = read_args,
         stopOnEntry = false,
      },
   }
end

return M
