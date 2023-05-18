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

local function _str_strip(s)
  return s:gsub("^%s+", ""):gsub("%s+$", "")
end

local function _str_escape(s)
  return s:gsub('"', '\"')
end

local function _is_filename_sane(filename)
  return not (filename:match("[^a-zA-Z0-9/\\%.%-_'()%[%] ]") and true or false)
end


local function _exec(cmd, strip)
  strip = strip ~= false
  local status_ok, pipe = pcall(io.popen, cmd)
  if not status_ok or not pipe then
    return nil
  end

  local result = pipe:read("*a")
  pipe:close()

  if strip and result then
    strip = _str_strip(result)
  end

  return result
end

---@diagnostic disable-next-line: redefined-local
function M.makedirs(dirname)
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
function M.read_file(filename)
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
function M.write_file(filename, data)
  if data == nil then
    data = ""
  end

  local parent_dir = dirname(filename)
  if parent_dir then
    M.makedirs(parent_dir)
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
function M.read_json(filename)
  if vimfn.filereadable(filename) <= 0 then
    return nil
  end

  local data = M.read_file(filename)
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
function M.write_json(filename, data)
  assert(type(filename) == "string", "filepath must be of type string")
  local status_ok, json_str = pcall(json.encode, data)
  if not status_ok or not json_str then
    status_ok, json_str = pcall(vimfn.json_encode, data)
  end
  if not status_ok or not json_str then
    return
  end
  M.write_file(filename, json_str)
end


---@param filename string path to file
---@return number? epoch_secs secs since unix epoch. may be a float
function M.created(filename)
  if not _is_filename_sane(filename) then
    return nil
  end

  local epoch_secs = nil

  -- allow windows in case gnu port is installed
  if not epoch_secs or epoch_secs <= 0 then
    local output = _exec("stat --format %W \""
      .. _str_escape(filename) .. "\"")
    epoch_secs = tonumber(output)
  end

  if (not epoch_secs or epoch_secs <= 0) and is_windows then
    local output = _exec("powershell -NoProfile -NoLogo -Command '(Get-Item \""
      .. _str_escape(filename)
      .. "\").CreationTime | Get-Date -UFormat %s'")
    epoch_secs = tonumber(output)
  end

  if (not epoch_secs or epoch_secs <= 0) and not is_windows then
    local output = _exec("find \"" .. _str_escape(filename)
      .. "\" -printf \"%Bs\"")
    epoch_secs = tonumber(output)
  end

  return epoch_secs and epoch_secs > 0 and epoch_secs or nil
end


---@param filename string path to file
---@return number? epoch_secs secs since unix epoch. may be a float
function M.modified(filename)
  if not _is_filename_sane(filename) then
    return nil
  end

  local epoch_secs = nil

  -- allow windows in case gnu port is installed
  if not epoch_secs or epoch_secs <= 0 then
    local output = _exec("stat --format %Y \""
      .. _str_escape(filename) .. "\"")
    epoch_secs = tonumber(output)
  end

  if (not epoch_secs or epoch_secs <= 0) and is_windows then
    local output = _exec("powershell -NoProfile -NoLogo -Command '(Get-Item \""
      .. _str_escape(filename)
      .. "\").LastWriteTime | Get-Date -UFormat %s'")
    epoch_secs = tonumber(output)
  end

  if (not epoch_secs or epoch_secs <= 0) and not is_windows then
    local output = _exec("date --utc +%s -r \""
      .. _str_escape(filename) .. "\"")
    epoch_secs = tonumber(output)
  end

  if (not epoch_secs or epoch_secs <= 0) and not is_windows then
    local output = _exec("find \"" .. _str_escape(filename)
      .. "\" -printf \"%Ts\"")
    epoch_secs = tonumber(output)
  end

  if not epoch_secs or epoch_secs <= 0 then
    return nil
  end

  return epoch_secs
end


---@param filename string path to file
---@return number? inode inode num if detected
function M.inode(filename)
  if not _is_filename_sane(filename) then
    return nil
  end

  local inode = nil

  if not inode or inode <= 0 then
    -- allow windows in case gow or equivalent is installed
    local output = _exec("stat --format %i \""
      .. _str_escape(filename) .. "\"")
    inode = tonumber(output)
  end

  if (not inode or inode <= 0) and not is_windows then
    local output = _exec("find \"" .. _str_escape(filename)
      .. "\" -printf \"%i\"")
    inode = tonumber(output)
  end

  if not inode or inode <= 0 then
    return nil
  end

  return inode
end


---@param filename string path to file
---@return number? file_id FileID if detected
function M.file_id(filename)
  if not _is_filename_sane(filename) then
    return nil
  end

  local file_id = nil

  if (not file_id or file_id <= 0) and is_windows then
    local output = _exec("fsutil file queryFileID \""
      .. _str_escape(filename) .. "\"")
    output = output and output:match("%s+(0x[a-fA-F0-9]+)%s*$") or nil
    file_id = tonumber(output)
  end

  if not file_id or file_id <= 0 then
    return nil
  end

  return file_id
end


return M
