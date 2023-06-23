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

  local dir = cwd or "."
  if script:match("[\\/][^\\/]+$") then
    dir = dir .. "/" .. script:gsub("[\\/]+[^\\/]*$", "")
  end

  return dir
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
}

luaunit.LuaUnit.run()
