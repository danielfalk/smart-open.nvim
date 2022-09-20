---@diagnostic disable: lowercase-global
-- This file itself
files[".luacheckrc"].ignore = { "111", "112", "131" }

-- Rerun tests only if their modification time changed.
cache = true

globals = {
  "vim",
  "_",
}

-- Global objects defined by the C code
read_globals = {
  "describe",
  "it",
  "assert",
}
