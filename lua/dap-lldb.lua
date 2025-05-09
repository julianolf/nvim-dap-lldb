---@mod dap-lldb LLDB extension for nvim-dap

---@brief [[
---An extension for nvim-dap to provide C, C++, and Rust debugging support.
---@brief ]]

local M = {}

local sep = package.config:sub(1, 1)

local ts_query = [[
(mod_item
  name: (identifier) @module
  body: (declaration_list
    (attribute_item (attribute (identifier) @attribute (#eq? @attribute "test")))
    (function_item
      name: (identifier) @function)))
]]

local function require_dap()
   local ok, dap = pcall(require, "dap")
   assert(ok, "nvim-dap is required to use dap-lldb")
   return dap
end

local function compiler_error(input)
   local _, json = pcall(vim.fn.json_decode, input)

   if type(json) == "table" and json.reason == "compiler-message" then
      return json.message.rendered
   end

   return nil
end

local function compiler_target(input)
   local _, json = pcall(vim.fn.json_decode, input)

   if
      type(json) == "table"
      and json.reason == "compiler-artifact"
      and json.executable ~= nil
      and (vim.tbl_contains(json.target.kind, "bin") or json.profile.test)
   then
      return json.executable
   end

   return nil
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
      local errors = vim.tbl_map(compiler_error, out)
      vim.notify(table.concat(errors, "\n"), vim.log.levels.ERROR)
      return nil
   end

   local function filter(e)
      return e ~= nil
   end

   return vim.tbl_filter(filter, vim.tbl_map(compiler_target, out))
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

local function select_test()
   local filetype = vim.bo.filetype

   if filetype ~= "rust" or vim.treesitter.language.get_lang(filetype) == nil then
      return nil
   end

   local bufnr = vim.api.nvim_get_current_buf()
   local query = vim.treesitter.query.parse(filetype, ts_query)
   local parser = vim.treesitter.get_parser(bufnr, filetype)
   local tree = parser:parse()[1]
   local root = tree:root()
   local stop = vim.api.nvim_win_get_cursor(0)[1]
   local mod = nil
   local fun = nil

   for id, node in query:iter_captures(root, bufnr, 0, stop) do
      local capture = query.captures[id]

      if capture == "module" then
         mod = vim.treesitter.get_node_text(node, 0)
      elseif capture == "function" then
         fun = vim.treesitter.get_node_text(node, 0)
      end
   end

   if not mod or not fun then
      return nil
   end

   return string.format("%s::%s", mod, fun)
end

local function read_args()
   local args = vim.fn.input("Enter args: ")
   return vim.split(args, " ", { trimempty = true })
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
      vim.tbl_extend("force", cfg, { name = "Attach debugger", request = "attach" }),
   }

   dap.configurations.cpp = vim.tbl_extend("keep", {}, dap.configurations.c)

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
      vim.tbl_extend("force", cfg, {
         name = "Debug test (cursor)",
         program = function()
            return select_target("tests")
         end,
         args = function()
            local test = select_test()
            local args = test and { "--exact", test } or {}
            return vim.list_extend(args, { "--test-threads=1" })
         end,
      }),
      vim.tbl_extend("force", cfg, { name = "Attach debugger", request = "attach", program = select_target }),
   }
end

local function custom_configurations(dap, opts)
   if type(opts.configurations) == "table" then
      for lang, cfg in pairs(opts.configurations) do
         local config = dap.configurations[lang] or {}
         dap.configurations[lang] = vim.list_extend(config, cfg)
      end
   end
end

---@class SetupOpts
---@field codelldb_path string|nil Path to CodeLLDB extension
---@field configurations table|nil Per programming language configuration
---@see https://github.com/vadimcn/codelldb/blob/master/MANUAL.md

---Register LLDB debug adapter
---@param opts SetupOpts|nil See |dap-lldb.SetupOpts|
function M.setup(opts)
   opts = type(opts) == "table" and opts or {}

   local dap = require_dap()
   local codelldb = opts.codelldb_path or "codelldb"

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

---Debug test function above the cursor
function M.debug_test()
   if vim.bo.filetype ~= "rust" then
      vim.notify("This feature is available only for Rust", vim.log.levels.ERROR)
      return nil
   end

   local dap = require_dap()
   local cfg = dap.configurations.rust[5]
   dap.run(cfg)
end

return M
