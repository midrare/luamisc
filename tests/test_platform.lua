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
local platform = require("platform")
local tables = require("tables")

TEST_PLATFORM = {
}

os.exit(luaunit.LuaUnit.run())
