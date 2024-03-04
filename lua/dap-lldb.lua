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

local function compiler_errors(input)
   local _, json = pcall(vim.fn.json_decode, input)

   if type(json) == "table" and json.reason == "compiler-message" then
      return json.message.rendered
   end

   return nil
end

local function map_targets(stdout)
   local targets = {}

   for _, line in ipairs(stdout) do
      local _, json = pcall(vim.fn.json_decode, line)

      if
         type(json) == "table"
         and json.reason == "compiler-artifact"
         and json.executable ~= nil
         and (vim.tbl_contains(json.target.kind, "bin") or json.profile.test)
      then
         table.insert(targets, json.executable)
      end
   end

   return targets
end

local function read_target()
   local cwd = string.format("%s%s", vim.fn.getcwd(), sep)
   return vim.fn.input("Path to executable: ", cwd, "file")
end

local function list_targets(selection)
   local arg = string.format("--%s", selection or "bins")
   local cmd = { "cargo", "build", arg, "--quiet", "--message-format", "json" }
   local out = vim.fn.systemlist(cmd)

   if vim.v.shell_error ~= 0 then
      local errors = vim.tbl_map(compiler_errors, out)
      vim.notify(table.concat(errors, "\n"), vim.log.levels.ERROR)
      return nil
   end

   return map_targets(out)
end

local function select_target(selection)
   local targets = list_targets(selection)

   if targets == nil then
      return nil
   end

   if #targets == 0 then
      return read_target()
   end

   if #targets == 1 then
      return targets[1]
   end

   local options = { "Select a target:" }

   for index, target in ipairs(targets) do
      local parts = vim.split(target, sep, { trimempty = true })
      local option = string.format("%d. %s", index, parts[#parts])
      table.insert(options, option)
   end

   local choice = vim.fn.inputlist(options)

   return targets[choice]
end

local function read_args()
   local args = vim.fn.input("Enter args: ")
   return vim.split(args, " ", { trimempty = true })
end

local function read_conf(path)
   local file = assert(io.open(path, "r"))
   local content = file:read("*all")

   file:close()

   local _, json = pcall(vim.fn.json_decode, content)

   if type(json) == "table" and type(json.configurations) == "table" then
      return json.configurations
   end

   return {}
end

local function default_configurations(dap)
   local cfg = {
      name = "Debug",
      type = "lldb",
      request = "launch",
      cwd = "${workspaceFolder}",
      program = read_target,
      stopOnEntry = false,
   }

   dap.configurations.c = {
      cfg,
      vim.tbl_extend("force", cfg, { name = "Debug (+args)", args = read_args }),
   }

   dap.configurations.cpp = dap.configurations.c

   dap.configurations.rust = {
      vim.tbl_extend("force", cfg, { program = select_target }),
      vim.tbl_extend("force", cfg, { name = "Debug (+args)", program = select_target, args = read_args }),
      vim.tbl_extend("force", cfg, {
         name = "Debug tests",
         program = function()
            return select_target("tests")
         end,
         args = { "--test-threads=1" },
      }),
      vim.tbl_extend("force", cfg, {
         name = "Debug tests (+args)",
         program = function()
            return select_target("tests")
         end,
         args = function()
            return vim.list_extend(read_args(), { "--test-threads=1" })
         end,
      }),
   }
end

local function custom_configurations(dap, opts)
   if type(opts.configurations) == "table" then
      for lang, cfg in pairs(opts.configurations) do
         local config = {}

         if opts.extend_config then
            config = dap.configurations[lang] or {}
         end

         dap.configurations[lang] = vim.list_extend(config, cfg)
      end
   end

   if type(opts.launch_file) == "string" then
      local cfg = read_conf(opts.launch_file)
      local lang = vim.bo.filetype
      local config = {}

      if opts.extend_config then
         config = dap.configurations[lang] or {}
      end

      dap.configurations[lang] = vim.list_extend(config, cfg)
   end
end

function M.setup(opts)
   local dap = require_dap()
   local codelldb = opts.codelldb_path or find_codelldb() or "codelldb"

   dap.adapters.lldb = {
      type = "server",
      port = "${port}",
      executable = {
         command = codelldb,
         args = { "--port", "${port}" },
         detached = vim.loop.os_uname().sysname ~= "Windows",
      },
   }

   default_configurations(dap)
   custom_configurations(dap, opts)
end

return M
