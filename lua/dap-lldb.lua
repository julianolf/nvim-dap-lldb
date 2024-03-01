local M = {}

local sep = package.config:sub(1, 1)

local function require_dap()
   local ok, dap = pcall(require, "dap")
   assert(ok, "nvim-dap is required to use dap-lldb")
   return dap
end

local function find_codelldb()
   local ok, registry = pcall(require, "mason-registry")

   if ok and registry.is_installed("codelldb") then
      local pkg = registry.get_package("codelldb")
      return table.concat({ pkg:get_install_path(), "extension", "adapter", "codelldb" }, sep)
   end

   return nil
end

local function list_targets(build_selection)
   local selection = build_selection or "bins"
   local command = { "cargo", "build", "--" .. selection, "--quiet", "--message-format", "json" }
   local outputs = vim.fn.systemlist(command)
   local targets = {}

   local failed = vim.v.shell_error ~= 0
   local errors = {}

   for _, line in ipairs(outputs) do
      local _, json = pcall(vim.fn.json_decode, line)

      if type(json) ~= "table" then
         goto end_loop
      end

      if failed and json.reason == "compiler-message" then
         table.insert(errors, json.message.rendered)
      elseif
         not failed
         and json.reason == "compiler-artifact"
         and json.executable ~= nil
         and (
            (selection == "bins" and vim.tbl_contains(json.target.kind, "bin"))
            or (selection == "tests" and json.profile.test)
         )
      then
         table.insert(targets, json.executable)
      end

      ::end_loop::
   end

   if failed then
      vim.notify(table.concat(errors, "\n"), vim.log.levels.ERROR)
      return nil
   end

   return targets
end

local function select_target(build_selection)
   local targets = list_targets(build_selection)

   if targets == nil then
      return nil
   end

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

local base_conf = {
   name = "Debug",
   type = "codelldb",
   request = "launch",
   cwd = "${workspaceFolder}",
   program = select_target,
   stopOnEntry = false,
}

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
      base_conf,
      vim.tbl_extend("force", base_conf, {
         name = "Debug (+args)",
         args = read_args,
      }),
      vim.tbl_extend("force", base_conf, {
         name = "Debug tests",
         program = function()
            return select_target("tests")
         end,
         args = { "--test-threads=1" },
      }),
      vim.tbl_extend("force", base_conf, {
         name = "Debug tests (+args)",
         program = function()
            return select_target("tests")
         end,
         args = function()
            local args = read_args()
            return vim.list_extend(args, { "--test-threads=1" })
         end,
      }),
   }
end

return M
