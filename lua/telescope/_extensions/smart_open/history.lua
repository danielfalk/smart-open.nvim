local util = require("smart-open.util")
local Path = require("plenary.path")

-- The frequency measure has a decay rate because more recent
-- accesses are generally more significant than older ones
local HALF_LIFE_DAYS = 10

local decay_rate = math.log(2) / HALF_LIFE_DAYS

local M = {
  db = nil,
  opts = {
    ignore_patterns = { "*.git/*", "*/tmp/*", "*.pdf" },
  },
}

local function file_is_ignored(filepath, ignore_patterns)
  for _, pattern in pairs(ignore_patterns) do
    if util.filename_match(filepath, pattern) then
      return true
    end
  end

  return false
end

local function find_current_score(file, now)
  local time_left = (file.expiration - now) / 86400

  if time_left <= 0 then
    return 1
  else
    return math.exp(decay_rate * time_left)
  end
end

local function find_flat_score(file, now)
  -- This scoring method gives values that have a linear correspondence to the
  -- expiration date.  This is probably better for scoring because otherwise
  -- the difference between higher scored items and low score is very stark.

  return file.expiration - now
end

local function find_expiration(file, now)
  local current_score = find_current_score(file, now)

  -- A single access counts as 100 points
  current_score = current_score + 100

  -- Solve for the new expiration given the decay rate
  return math.floor(now + (math.log(current_score) / decay_rate) * 86400)
end

function M:record_usage(filepath, force)
  if not self.db then
    error("Failed to initialize db")
  end
  if util.string_isempty(filepath) then
    return
  end

  -- check if file is registered as loaded
  if force or not vim.b.telescope_smart_open_registered then
    -- allow [noname] files to go unregistered until BufWritePost
    local stat = util.fs_stat(filepath)
    if stat.isdirectory or not stat.exists then
      return
    end
    if file_is_ignored(filepath, self.opts.ignore_patterns) then
      return
    end

    vim.b.telescope_smart_open_registered = 1
    self:handle_open(filepath)
  end
end

function M:setup(db, opts)
  if self.db then
    return
  end

  self.db = db

  for key, value in pairs(opts) do
    self.opts[key] = value
  end

  if self.db.is_empty then
    ---@diagnostic disable-next-line: param-type-mismatch
    vim.defer_fn(function()
      self:batch_import()
      ---@diagnostic disable-next-line: param-type-mismatch
    end, 100)
  end

  local api = vim.api

  local group = api.nvim_create_augroup("TelescopeSmartOpen", { clear = true })
  api.nvim_create_autocmd({ "BufWinEnter", "BufWritePost" }, {
    callback = function(args)
      M:record_usage(args.match)
    end,
    group = group,
  })
end

function M:batch_import()
  local oldfiles = vim.api.nvim_get_vvar("oldfiles")

  for index, filepath in pairs(oldfiles) do
    -- 9000 works out to about 10 files per day
    local yesterday = os.time() - ((#oldfiles + 1) - index) * 9000

    local ok, err = pcall(function()
      self:handle_open(filepath, true, yesterday)
    end)
    if not ok then
      print("SmartOpen: Couldn't import", filepath, "Error:", err)
    end
  end

  print(("SmartOpen: Imported %d entries from oldfiles."):format(#oldfiles))
end

function M:get_all(dir)
  local result = dir and self.db:get_files_in(dir) or self.db:get_files()
  local now = os.time()

  local max_score = 1

  if not result or type(result) == "boolean" then
    return {}, max_score
  end

  for index, item in ipairs(result) do
    item.score = math.floor(find_flat_score(item, now))
    if index == 1 then
      max_score = item.score
    end
    item.max_score = max_score
    local stat = util.fs_stat(item.path)
    item.exists = stat.exists and not stat.isdirectory
  end

  return result, max_score
end

function M:handle_open(original_filepath, batch_mode, now)
  now = now or os.time()

  local filepath = Path:new(original_filepath):absolute()

  if filepath == "" or not filepath then
    print("[smart-open] Encountered a blank filepath:", original_filepath)
    return
  end

  local file = self.db:get_file(filepath, now)
  local new_expiration = find_expiration(file, now)

  self.db:update_file(filepath, new_expiration, now)

  if not batch_mode then
    self.db:delete_expired(now)
  end
end

return M
