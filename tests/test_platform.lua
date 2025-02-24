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

-- force reload
package.loaded["platform"] = nil

local old_package_path = package.path
local script_dir = get_script_dir()
package.path = script_dir .. "/?.lua;" .. script_dir .. "/../?.lua;"
local luaunit = require("luaunit")
local platform = require("platform")
package.path = old_package_path

TEST_PLATFORM = {
  test_read_winreg_value = function()
    if vim.fn.has("win32") >= 1 then
      local value = platform.read_winreg_value(
        "HKEY_LOCAL_MACHINE\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion",
        "ProgramFilesDir"
      )
      luaunit.assert_equals(value.type, "REG_SZ")
      luaunit.assert_eval_to_true(value.value)
      luaunit.assert_not_equals(value.value, "")
    end
  end,
  test_is_windows = function()
    luaunit.assert_equals(platform.is_windows(), vim.fn.has("win32") >= 1)
  end,
  test_cpu_procs = function()
    luaunit.assert_is_number(platform.cpu_procs())
  end,
  test_nvim_version = function()
    luaunit.assert_is_string(platform.nvim_version())
  end,
  test_run = function()
    local status, out, err = platform.run({vim.v.progpath, "--version"})
    luaunit.assert_equals(status, 0)
    luaunit.assert_str_contains(out, "NVIM")
    luaunit.assert_eval_to_false(err)
  end,
}

luaunit.LuaUnit.run()
