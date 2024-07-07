local splitlines = require("smart-open.util.splitlines")

local function safe_close(handle)
  if not vim.loop.is_closing(handle) then
    vim.loop.close(handle)
  end
end

local function spawn(cmd, opts, input, onexit)
  local handle
  -- open an new pipe for stdout
  local stdout = vim.loop.new_pipe(false)
  -- open an new pipe for stderr
  local stderr = vim.loop.new_pipe(false)
  local args = vim.tbl_extend("force", opts, { stdio = { nil, stdout, stderr } })

  handle = vim.loop.spawn(cmd, args, function(code, signal)
    -- call the exit callback with the code and signal
    onexit(code, signal)
    -- stop reading data to stdout
    vim.loop.read_stop(stdout)
    -- stop reading data to stderr
    vim.loop.read_stop(stderr)
    -- safely shutdown child process
    safe_close(handle)
    -- safely shutdown stdout pipe
    safe_close(stdout)
    -- safely shutdown stderr pipe
    safe_close(stderr)
  end)

  -- read child process output to stdout
  vim.loop.read_start(stdout, input.stdout)
  -- read child process output to stderr
  vim.loop.read_start(stderr, input.stderr)

  local function stop()
    -- stop reading data to stdout
    vim.loop.read_stop(stdout)
    -- stop reading data to stderr
    vim.loop.read_stop(stderr)
    -- safely shutdown child process
    safe_close(handle)
    -- safely shutdown stdout pipe
    safe_close(stdout)
    -- safely shutdown stderr pipe
    safe_close(stderr)
  end
  return stop
end

local function ripgrep_scan(opts, on_insert, on_complete)
  local stderr = ""
  local args = {
    "--files",
    "--glob-case-insensitive",
    "--line-buffered",
    "--color",
    "never",
    "--ignore-file",
    opts.cwd .. "/.ff-ignore",
  }

  for _, value in ipairs(opts.ignore_patterns) do
    table.insert(args, "-g")
    table.insert(args, "!" .. value)
  end

  if opts.hidden then
    args[#args + 1] = "--hidden"
  end

  if opts.no_ignore then
    args[#args + 1] = "--no-ignore"
  end

  if opts.no_ignore_parent then
    args[#args + 1] = "--no-ignore-parent"
  end

  if opts.follow then
    args[#args + 1] = "-L"
  end

  local done = false
  local stop

  local start_time
  stop = spawn("rg", { args = args, cwd = opts.cwd }, {
    stdout = function(_, chunk)
      if not start_time then
        start_time = vim.loop.uptime()
      end

      if done or not chunk then
        return
      end

      for line in splitlines(chunk) do
        if #line > 0 and on_insert(opts.cwd .. "/" .. line) == false then
          done = true
          stop()
          return vim.schedule(function()
            on_complete(0, "")
          end)
        end
      end
    end,
    stderr = function(s, data)
      stderr = stderr .. "\n" .. (data or s or "")
    end,
  }, function(_, return_val)
    return vim.schedule(function()
      on_complete(done and 0 or return_val, stderr)
    end)
  end)
end

return function(opts, on_insert, on_complete)
  ripgrep_scan(opts, on_insert, function(exit_code, err)
    if exit_code ~= 0 then
      print("ripgrep exited with code", exit_code, "and error:", err)
    end
    on_complete()
  end)
end
