local modulename, _ = ...
---@diagnostic disable-next-line: unused-local
local moduleroot = modulename and modulename:gsub("(.+)%..+", "%1") or nil

local function get_cwd()
  local cwd = nil

  if vim and vim.loop then
    cwd = vim.loop.cwd()
  else
    local pwd_cmd = (package.config:sub(1, 1) == "/" and "pwd") or "echo %cd%"
    local pipe = io.popen(pwd_cmd)
    cwd = pipe and pipe:read("*l")
    if pipe then
      pipe:close()
    end
  end

  local cwd_, _ = cwd
    :gsub("[\\/]+[%s\r\n]*$", "")
    :gsub("[\\/]+", "/")

  return cwd_
end

---@param source? string caller debug.getinfo(1).source
---@return string dir path to dir of calling script
---@nodiscard
local function get_script_dir(source)
  source = source or debug.getinfo(1).source
  local script = source:gsub("^@", ""):gsub("[\\/]", "/")
  local script_dir = script:gsub("[\\/]+[^\\/]*$", "")

  if script_dir:match("^[a-zA-Z]:[\\/]") then
    -- absolute win path
    return "" .. script_dir
  elseif script_dir:match("^[\\/]") then
    -- absolute unix path
    return "" .. script_dir
  else
    -- relative path; must prepend cwd
    local cwd = get_cwd() or "."
    return cwd .. "/" .. script_dir
  end
end

local old_package_path = package.path
local script_dir = get_script_dir()
package.path = script_dir .. "/?.lua;" .. script_dir .. "/../?.lua;"
local luaunit = require("luaunit")
package.loaded["arrays"] = nil
local arrays = require("arrays")
package.path = old_package_path


---@diagnostic disable-next-line: unused-function, unused-local
TEST_IS_ARRAY = {
  test_default = function()
    local items = { "a", "b", "c", "d" }
    luaunit.assert_is_true(arrays.is_array(items))
  end,
  test_explicit = function()
    local items = {[1] = "a", [2] = "b", [3] = "c", [4] = "d"}
    luaunit.assert_is_true(arrays.is_array(items))
  end,
  test_left_gap = function()
    local items = {[2] = "b", [3] = "c", [4] = "d", [5] = "e"}
    luaunit.assert_is_false(arrays.is_array(items))
  end,
  test_mid_gap = function()
    local items = {[1] = "a", [2] = "b", [4] = "d", [5] = "e"}
    luaunit.assert_is_false(arrays.is_array(items))
  end,
  test_right_gap = function()
    local items = {[1] = "a", [2] = "b", [3] = "c", [4] = "d"}
    luaunit.assert_is_true(arrays.is_array(items))
  end,
  test_empty = function()
    local items = {}
    luaunit.assert_is_false(arrays.is_array(items))
  end,
  test_bad_left = function()
    local items = {foo = "bar", [2] = "b", [3] = "c", [4] = "d"}
    luaunit.assert_is_false(arrays.is_array(items))
  end,
  test_bad_mid = function()
    local items = {[1] = "a", [2] = "b", foo = "bar", [4] = "d"}
    luaunit.assert_is_false(arrays.is_array(items))
  end,
  test_bad_right = function()
    local items = {[1] = "a", [2] = "b", [3] = "c", foo = "bar"}
    luaunit.assert_is_false(arrays.is_array(items))
  end,
  test_default_nonlinear = function()
    local items = { "a", "b", "c", "d", "e" }
    luaunit.assert_is_true(arrays.is_array(items, false))
  end,
  test_explicit_nonlinear = function()
    local items = {[1] = "a", [2] = "b", [3] = "c", [4] = "d"}
    luaunit.assert_is_true(arrays.is_array(items, false))
  end,
  test_left_gap_nonlinear = function()
    local items = {[2] = "b", [3] = "c", [4] = "d", [5] = "e"}
    luaunit.assert_is_true(arrays.is_array(items, false))
  end,
  test_mid_gap_nonlinear = function()
    local items = {[1] = "a", [2] = "b", [4] = "d", [5] = "e"}
    luaunit.assert_is_true(arrays.is_array(items, false))
  end,
  test_right_gap_nonlinear = function()
    local items = {[1] = "a", [2] = "b", [3] = "c", [4] = "d"}
    luaunit.assert_is_true(arrays.is_array(items, false))
  end,
  test_empty_nonlinear = function()
    local items = {}
    luaunit.assert_is_false(arrays.is_array(items, false))
  end,
  test_bad_left_nonlinear = function()
    local items = {foo = "bar", [2] = "b", [3] = "c", [4] = "d"}
    luaunit.assert_is_false(arrays.is_array(items, false))
  end,
  test_bad_mid_nonlinear = function()
    local items = {[1] = "a", [2] = "b", foo = "bar", [4] = "d"}
    luaunit.assert_is_false(arrays.is_array(items, false))
  end,
  test_bad_right_nonlinear = function()
    local items = {[1] = "a", [2] = "b", [3] = "c", foo = "bar"}
    luaunit.assert_is_false(arrays.is_array(items, false))
  end,
}


---@diagnostic disable-next-line: unused-function, unused-local
TEST_GET_FROM = {
  test_forwards = function()
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
  test_backwards = function()
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

luaunit.LuaUnit.run()
