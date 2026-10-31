local function run()
   vim.opt.runtimepath:append(".")

   local dap = { adapters = {}, configurations = {}, ABORT = {} }
   package.loaded.dap = dap
   require("dap-lldb").setup()

   local function check(actual, expected)
      assert(vim.deep_equal(actual, expected), vim.inspect({ actual = actual, expected = expected }))
   end

   -- Exercise the suspended-thread contract used by nvim-dap to resolve config values.
   local function resolve(option, delayed)
      local thread = option()
      assert(type(thread) == "thread" and coroutine.status(thread) == "suspended", "Expected a suspended config thread")
      local result
      local waiter = coroutine.create(function()
         result = coroutine.yield()
      end)
      assert(coroutine.resume(waiter))
      assert(coroutine.resume(thread, waiter))
      if delayed then
         assert(coroutine.status(waiter) == "suspended", "Input resumed before the asynchronous callback")
      end
      assert(vim.wait(1000, function()
         return coroutine.status(waiter) == "dead"
      end))
      return result
   end

   local prompts = {}
   local function input(value, delayed)
      vim.ui.input = function(opts, callback)
         table.insert(prompts, opts)
         if delayed then
            vim.schedule(function()
               callback(value)
            end)
         else
            callback(value)
         end
      end
   end

   vim.fn.input = function()
      error("Must use vim.ui.input for executable paths and arguments")
   end

   for _, delayed in ipairs({ false, true }) do
      for _, language in ipairs({ "c", "cpp" }) do
         local configs = dap.configurations[language]
         input("/tmp/example program", delayed)
         check(resolve(configs[1].program, delayed), "/tmp/example program")
         check(prompts[#prompts], {
            prompt = "Path to executable: ",
            default = vim.fs.joinpath(vim.fn.getcwd(), ""),
            completion = "file",
         })
         input(nil, delayed)
         assert(resolve(configs[1].program, delayed) == dap.ABORT, "Cancelled path must abort launch")
         input("", delayed)
         assert(resolve(configs[1].program, delayed) == dap.ABORT, "Empty path must abort launch")

         input(" first  second ", delayed)
         check(resolve(configs[2].args, delayed), { "first", "", "second" })
         input("", delayed)
         check(resolve(configs[2].args, delayed), {})
         input(nil, delayed)
         assert(resolve(configs[2].args, delayed) == dap.ABORT, "Cancelled arguments must abort launch")
      end

      input("--nocapture", delayed)
      check(resolve(dap.configurations.rust[4].args, delayed), { "--nocapture", "--test-threads=1" })
      input("", delayed)
      check(resolve(dap.configurations.rust[4].args, delayed), { "--test-threads=1" })
      input(nil, delayed)
      assert(
         resolve(dap.configurations.rust[4].args, delayed) == dap.ABORT,
         "Cancelled test arguments must abort launch"
      )

      local targets = { "/tmp/target/debug/one", "/tmp/target/debug/two" }
      vim.fn.systemlist = function()
         return vim.tbl_map(function(target)
            return vim.json.encode({
               reason = "compiler-artifact",
               executable = target,
               target = { kind = { "bin" } },
               profile = { test = false },
            })
         end, targets)
      end
      vim.fn.inputlist = function()
         error("Must use vim.ui.select for multiple targets")
      end
      local choice = targets[2]
      vim.ui.select = function(items, opts, callback)
         check(items, targets)
         check(opts.prompt, "Select a target:")
         check(opts.format_item(targets[2]), "two")
         if delayed then
            vim.schedule(function()
               callback(choice)
            end)
         else
            callback(choice)
         end
      end
      check(resolve(dap.configurations.rust[1].program, delayed), targets[2])
      choice = nil
      assert(
         resolve(dap.configurations.rust[1].program, delayed) == dap.ABORT,
         "Cancelled target selection must abort launch"
      )

      targets = { targets[1] }
      vim.ui.select = function()
         error("A single target should be selected automatically")
      end
      check(dap.configurations.rust[1].program(), targets[1])
      targets = {}
      input("/tmp/fallback", delayed)
      check(resolve(dap.configurations.rust[1].program, delayed), "/tmp/fallback")
      input(nil, delayed)
      assert(
         resolve(dap.configurations.rust[1].program, delayed) == dap.ABORT,
         "Cancelled fallback path must abort launch"
      )
   end

   print("UI prompts: synchronous and asynchronous callbacks, cancellation, argument parsing, and Rust targets passed")
end

local ok, err = xpcall(run, debug.traceback)
if not ok then
   vim.api.nvim_err_writeln(err)
   vim.cmd("cquit 1")
end
vim.cmd("qa!")
