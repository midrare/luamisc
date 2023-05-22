local M = {}

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

local old_package_path = package.path
package.path = get_script_dir() .. "/?.lua"
M.arrays = require("arrays")
M.base64 = require("base64")
M.bit = require("bit")
M.date = require("date")
M.files = require("files")
M.json = require("json")
M.paths = require("paths")
M.platform = require("platform")
M.sha2 = require("sha2")
M.strings = require("strings")
M.tables = require("tables")
M.utf8 = require("utf8")
M.yaml = require("yaml")
package.path = old_package_path

return M
