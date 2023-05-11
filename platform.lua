local modulename, _ = ...
---@diagnostic disable-next-line: unused-local
local moduleroot = modulename:gsub("(.+)%..+", "%1")

local module = {}


local is_windows = (function()
  local is_ok, has_win = pcall(vim.fn.has, "win32")
  if is_ok then
    return has_win > 0
  end
  return package.config:sub(1, 1) == '\\'
end)()


local function _exec(cmd)
  local status_ok, pipe = pcall(io.popen, cmd)
  if not status_ok or not pipe then
    return nil
  end

  local result = pipe:read("*a")
  pipe:close()

  return result
end

local function _to_lines(s)
  local lines = {}

  while s and #s > 0 do
    local eol, _ = s:find("\n", 1, true)

    local line = s
    if eol then
      s:sub(1, eol)
      s = s:sub(eol + 1)
    else
      s = ""
    end

    line = line:gsub("[%s\r\n]+$", "")
    table.insert(lines, line)
  end

  return lines
end

local function _strip(s)
  return s:gsub("^%s+", ""):gsub("%s+$", "")
end

---@return integer? procs number of processors detected
---@nodiscard
function module.cpu_procs()
  local s = os.getenv("NUMBER_OF_PROCESSORS")

  if s == nil or s:match("^%s*$") then
    local is_ok, handle = pcall(io.popen, "nproc -all 2>&1")
    if is_ok and handle ~= nil then
      s = handle:read("*a")
      handle:close()
    end
  end

  if s == nil or s:match("^%s*$") then
    return nil
  end

  s = s:match("^%s*(.*%S)%s*$")
  return tonumber(s)
end

---@return boolean is_win true if current os is windows
---@nodiscard
function module.is_windows()
  return is_windows
end

---@return string ver_str neovim version string
---@nodiscard
function module.nvim_version()
  local ver_str = vim.fn.execute("version")
  return ver_str:match("^.+ +v([%d.]+)[-_%s]*([%w._-]*)\r?\n")
end


---@package
---@alias regval { type: string, value: number|string }

---@param key string path to registry key
---@return string[] keys, table<string, regval> values, regval? default
---@nodiscard
function module.read_winreg(key)
  assert(type(key) == "string", "key must be a string")

  if not is_windows then
    return {}, {}, nil
  end

  local subkeys = {}
  local values = {}
  local default = nil

  key = key
    :gsub("[\\/]+", "\\")
    :gsub("[\\/]+$", "")
    :gsub("[^a-zA-Z0-9_\\-\\/\\. ]", "")

  local out = _exec('reg.exe query "' .. key .. '"')
  local lines = _to_lines(out)

  -- skip prelude
  while
    lines[1]
    and (lines[1]:match("^[%s\r\n]*$") or lines[1]:match("^[^%s\r\n]"))
  do
    table.remove(lines, 1)
  end

  for _, line in ipairs(lines) do
    if line:match("^%s+") then
      -- line specifies a value
      local name, type_, value = line:match("^%s+(.+)%s+(REG_[%w_]+)%s+(.*)$")
      if name and type_ then
        name = _strip(name)
        value = _strip(value)

        local entry = { type = type_, value = value }

        if name == "(Default)" then
          default = entry
        else
          values[name] = entry
        end
      end
    elseif line:match("^[^%s]") then
      -- line specifies a sub-key
      local keyname = _strip(line)
      if keyname and #keyname > 0 then
        table.insert(subkeys, keyname)
      end
    end
  end

  return subkeys, values, default
end

---@param key string registry key
---@param name? string value name
---@return regval? value value read from registry
function module.read_winreg_value(key, name)
  if not is_windows then
    return nil
  end

  key = key
    :gsub("[\\/]+", "\\")
    :gsub("[\\/]+$", "")
    :gsub("[^a-zA-Z0-9_\\-\\/\\. ]", "")

  local _, values, default = module.read_winreg(key)

  if not name or #name <= 0 then
    return default
  end

  return values and values[name] or nil
end

return module
