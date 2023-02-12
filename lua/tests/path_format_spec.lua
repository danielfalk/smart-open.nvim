local format_filepath = require("telescope._extensions.smart_open.display.format_filepath")
local os_home = vim.loop.os_homedir()

describe("format_filepath with maxlen", function()
  it("doesn't truncate shorter paths", function()
    local expected = "hosts /etc"
    local result = format_filepath("/etc/hosts", "hosts", { cwd = "/other", filename_first = true }, 30)
    assert.are.equal(expected, result)
  end)

  it("handles virtual filenames appropriately", function()
    local expected = "foo/init.lua src/largedirecto…"
    local result = format_filepath(
      "/base/src/largedirectoryname/foo/init.lua",
      "foo/init.lua",
      { cwd = "/base", filename_first = true },
      30
    )
    assert.are.equal(expected, result)
  end)

  it("uses relative path while shortening", function()
    local expected = "filename.lua src/largedirecto…"
    local result = format_filepath(
      "/base/src/largedirectoryname/filename.lua",
      "filename.lua",
      { cwd = "/base", filename_first = true },
      30
    )
    assert.are.equal(expected, result)
  end)

  it("abbreviates home directory while shortening when cwd is outside home", function()
    local expected = "filename.lua ~/src/LargeDirec…"
    local result = format_filepath(
      os_home .. "/src/LargeDirectoryName/filename.lua",
      "filename.lua",
      { cwd = "/", filename_first = true },
      30
    )
    assert.are.equal(expected, result)
  end)

  it("doesn't use abbreviated home directory when path can be relative", function()
    local expected = "filename.lua src/LargeDirecto…"
    local result = format_filepath(
      os_home .. "/code/src/LargeDirectoryName/filename.lua",
      "filename.lua",
      { cwd = os_home .. "/code", filename_first = true },
      30
    )
    assert.are.equal(expected, result)
  end)

  it("displays the right number of characters", function()
    local path = "/base/lua/telescope/_extensions/smart_open/display/format_filepath.lua"
    local result = format_filepath(path, "format_filepath.lua", { cwd = "/base", filename_first = true }, 61)
    assert.are.equal(61, vim.fn.strdisplaywidth(result))
  end)

  it("abbreviates home directory while shortening when cwd is inside home", function()
    local expected = "filename.lua ~/src/LargeDirec…"
    local result = format_filepath(
      os_home .. "/src/LargeDirectoryName/filename.lua",
      "filename.lua",
      { cwd = os_home .. "/other_dir", filename_first = true },
      30
    )
    assert.are.equal(expected, result)
  end)
end)
