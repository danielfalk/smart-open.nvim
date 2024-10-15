local util = require("smart-open.util")
local shallow_copy = require("smart-open.util.table").shallow_copy
local has_sqlite, sqlite = pcall(require, "sqlite")

if not has_sqlite then
  error("This plugin requires sqlite.lua (https://github.com/kkharji/sqlite.lua) " .. tostring(sqlite))
end

local DbClient = {
  path = "",
  is_empty = false,
  Memory = {},
}

function DbClient:new(o)
  o = o or {}
  setmetatable(o, self)
  self.__index = self

  if not o.path or o.path == nil then
    error("No path was supplied")
  end

  if o.path == DbClient.Memory then
    self.db = sqlite:open()
    self:initialize_db()
  else
    self.db = sqlite:open(o.path)
    if not self.db:exists("files") then
      self:initialize_db()
    end
  end
  self.db:eval([[ PRAGMA synchronous = NORMAL ]])
  self.db:eval([[ PRAGMA journal_mode = WAL ]])
  return o
end

function DbClient:initialize_db()
  self.db:eval([[
  CREATE TABLE weights (key TEXT PRIMARY KEY, value NUMBER) WITHOUT ROWID
  ]])
  self.db:eval([[
  CREATE TABLE files (path TEXT PRIMARY KEY, expiration NUMBER, last_open NUMBER) WITHOUT ROWID
  ]])
  self.db:eval([[ CREATE INDEX expiry ON files (expiration) ]])
  self.db:eval([[ CREATE INDEX recent ON files (last_open) ]])
  self.is_empty = true
end

function DbClient:update_file(filepath, expiration, now)
  self.db:eval(
    [[
  INSERT INTO files (path, expiration, last_open)
  VALUES (:path, :expiration, :last_open)
  ON CONFLICT(path) DO
  UPDATE SET expiration = :expiration, last_open = :last_open
    ]],
    { path = filepath, expiration = expiration, last_open = now }
  )
end

function DbClient:delete_expired(now)
  -- Clean up when opening a file
  self.db:eval(
    [[
    DELETE FROM files WHERE expiration <= :expiration
      ]],
    { expiration = now }
  )
end

function DbClient:get_file(filepath, now)
  local result = self.db:select("files", { where = { path = filepath } })
  return #result > 0 and result[1] or {
    path = filepath,
    expiration = now - 1,
  }
end

function DbClient:get_files_in(dir, now)
  now = now or os.time()

  local result = self.db:eval(
    [[
  SELECT path, expiration, RANK() OVER ( ORDER BY last_open DESC ) AS recent_rank FROM files
  WHERE expiration > :now AND instr(path, :dir) == 1
  ORDER BY expiration DESC
    ]],
    { now = now, dir = dir:sub(-1) == "/" and dir or dir .. "/" }
  )

  return result
end

function DbClient:get_files(now)
  now = now or os.time()

  local result = self.db:eval(
    [[
  SELECT path, expiration, RANK() OVER ( ORDER BY last_open DESC ) AS recent_rank FROM files
  WHERE expiration > :now
  ORDER BY expiration DESC
    ]],
    { now = now }
  )

  return result
end

function DbClient:get_weights(default_weights)
  local weights = shallow_copy(default_weights)
  local result = self.db:eval([[ SELECT key, value from weights ]])
  if result and type(result) ~= "boolean" then
    for _, v in pairs(result) do
      weights[v.key] = v.value
    end
  end
  return weights
end

function DbClient:save_weights(weights)
  for k, v in pairs(weights) do
    if v ~= nil then
      self.db:eval(
        [[
  INSERT INTO weights (key, value)
  VALUES (:key, :value)
  ON CONFLICT(key) DO
  UPDATE SET value = :value
        ]],
        { key = k, value = v }
      )
    end
  end
end

function DbClient:validate()
  local files = self.db:select("files")
  for _, result in ipairs(files) do
    if util.fs_stat(result.path).exists then
      self.db:delete("files", { where = { path = result.path } })
    end
  end
end

return DbClient
