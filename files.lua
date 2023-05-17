local module, _ = {}, nil
module.name, _ = ...

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

local old_package_path = package.path
package.path = get_script_dir() .. "/?.lua"
local json = require("json")
package.path = old_package_path

local vimfn = (vim or {}).fn or {}

local is_windows = (function()
  local is_ok, has_win = pcall(vimfn.has, "win32")
  if is_ok then
    return has_win > 0
  end
  return package.config:sub(1, 1) == "\\"
end)()

local function dirname(filename)
  local d = filename:match("^(.*[\\/]).+$")
  if d ~= nil then
    d = d:match("^(.+)[\\/]+$") or d
  end
  return d
end

local function fix_numeric_keys(o)
  if type(o) ~= "table" then
    return o
  end

  local remapped = {}

  for key, value in pairs(o) do
    if type(key) == "string" then
      key = tonumber(key) or key
    end

    if type(value) == "table" then
      value = fix_numeric_keys(value)
    end

    remapped[key] = value
  end

  return remapped
end

---@diagnostic disable-next-line: redefined-local
function module.makedirs(dirname)
  local is_ok, _ = pcall(vimfn.mkdir, dirname, "p")
  if is_ok then
    return true
  end

  if dirname:match("^[a-zA-Z0-9_-\\/ %.']+$") then
    dirname = dirname:gsub("[\\/]", "/") -- prevent char escapes
    if is_windows then
      os.execute('cmd.exe /E:ON /F:OFF /V:OFF /Q "' .. dirname .. '"')
    else
      os.execute('mkdir -p "' .. dirname .. '"')
    end
    return true
  end

  return false
end

---@param filename string path to file
---@return any? data file contents
---@nodiscard
function module.read_file(filename)
  local file = io.open(filename, "r")
  if not file then
    return nil
  end

  local data = file:read("*a")
  file:close()

  return data
end

---@param filename string path to file
---@param data? any data to write
---@return boolean status true if write ok
function module.write_file(filename, data)
  if data == nil then
    data = ""
  end

  local parent_dir = dirname(filename)
  if parent_dir then
    module.makedirs(parent_dir)
  end

  local file = io.open(filename, "w")
  if not file then
    return false
  end

  file:write(data)
  file:close()
  file = nil

  return true
end

---@param filename string path to json file
---@return any? data parsed file contents
---@nodiscard
function module.read_json(filename)
  if vimfn.filereadable(filename) <= 0 then
    return nil
  end

  local data = module.read_file(filename)
  if not data then
    return nil
  end

  local status_ok, json_obj = pcall(json.decode, data)
  if not status_ok or not json_obj then
    status_ok, json_obj = pcall(vimfn.json_decode, data)
  end
  if not status_ok or not json_obj then
    return nil
  end

  return fix_numeric_keys(json_obj)
end

---@param filename string path to json file
---@param data? any data to encode as json and write
function module.write_json(filename, data)
  assert(type(filename) == "string", "filepath must be of type string")
  local status_ok, json_str = pcall(json.encode, data)
  if not status_ok or not json_str then
    status_ok, json_str = pcall(vimfn.json_encode, data)
  end
  if not status_ok or not json_str then
    return
  end
  module.write_file(filename, json_str)
end

return module
