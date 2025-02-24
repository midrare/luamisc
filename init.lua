local M = {}

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
