local modulename, _ = ...
---@diagnostic disable-next-line: unused-local
local moduleroot = modulename and modulename:gsub("(.+)%..+", "%1") or nil

---@param source? string caller debug.getinfo(1).source
---@return string dir path to dir of calling script
---@nodiscard
local function get_script_dir(source)
  source = source or debug.getinfo(1).source
  local script = source:gsub("^@", ""):gsub("[\\/]", "/")
  if script:match("^[a-zA-Z]:[\\/]") then
    return "" .. script:gsub("[\\/]+[^\\/]*$", "")
  end
  local pwd_cmd = package.config:sub(1, 1) == "/" and "pwd" or "echo %cd%"
  local pipe = io.popen(pwd_cmd)
  local cwd = pipe and pipe:read("*l"):gsub("[\\/]+$", ""):gsub("[\\/]", "/")
  if pipe then
    pipe:close()
  end
  return cwd .. "/" .. script:gsub("[\\/]+[^\\/]*$", "")
end

package.path = package.path
  .. ";"
  .. get_script_dir()
  .. "/?.lua"
  .. ";"
  .. get_script_dir()
  .. "/../?.lua"
local luaunit = require("luaunit")
local arrays = require("arrays")

---@diagnostic disable-next-line: unused-function, unused-local
TEST_ARRAYS = {
  test_get_from_forwards = function()
    local items = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 }
    luaunit.assert_equals(arrays.get_from(items, 0, 0), {})
    luaunit.assert_equals(arrays.get_from(items, 0, 1), { 1 })
    luaunit.assert_equals(arrays.get_from(items, 1, 1), { 1 })
    luaunit.assert_equals(arrays.get_from(items, 0, 3), { 1, 2, 3 })
    luaunit.assert_equals(arrays.get_from(items, 1, 3), { 1, 2, 3 })
    luaunit.assert_equals(arrays.get_from(items, 4, 6), { 4, 5, 6 })
    luaunit.assert_equals(arrays.get_from(items, 8, 10), { 8, 9, 10 })
    luaunit.assert_equals(arrays.get_from(items, 8, 11), { 8, 9, 10 })
    luaunit.assert_equals(arrays.get_from(items, 8, 99), { 8, 9, 10 })
    luaunit.assert_equals(arrays.get_from(items, 10, 99), { 10 })
    luaunit.assert_equals(arrays.get_from(items, 11, 99), {})
    luaunit.assert_equals(arrays.get_from(items, 99, 99), {})
    luaunit.assert_equals(arrays.get_from(items, 99, 999), {})
    luaunit.assert_equals(arrays.get_from(items, 999, 99), {})
  end,
  test_get_from_backwards = function()
    local items = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 }
    luaunit.assert_equals(arrays.get_from(items, 99, 999), {})
    luaunit.assert_equals(arrays.get_from(items, 999, 99), {})
    luaunit.assert_equals(arrays.get_from(items, 99, 99), {})
    luaunit.assert_equals(arrays.get_from(items, 99, 11), {})
    luaunit.assert_equals(arrays.get_from(items, 99, 10), { 10 })
    luaunit.assert_equals(arrays.get_from(items, 99, 8), { 10, 9, 8 })
    luaunit.assert_equals(arrays.get_from(items, 11, 8), { 10, 9, 8 })
    luaunit.assert_equals(arrays.get_from(items, 10, 8), { 10, 9, 8 })
    luaunit.assert_equals(arrays.get_from(items, 6, 4), { 6, 5, 4 })
    luaunit.assert_equals(arrays.get_from(items, 3, 1), { 3, 2, 1 })
    luaunit.assert_equals(arrays.get_from(items, 3, 0), { 3, 2, 1 })
    luaunit.assert_equals(arrays.get_from(items, 1, 1), { 1 })
    luaunit.assert_equals(arrays.get_from(items, 1, 0), { 1 })
    luaunit.assert_equals(arrays.get_from(items, 0, 0), {})
  end,
}

os.exit(luaunit.LuaUnit.run())
