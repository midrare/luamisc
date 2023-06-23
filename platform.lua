local M = {}

local is_windows = vim.fn.has("win32") >= 1
local path_sep = vim.fn.has("win32") >= 1 and "\\" or "/"

local Process = {}

function Process:new(o)
  local opts = o
  o = setmetatable({}, self)
  self.__index = self

  self._cmd = opts.cmd
  self._cwd = opts.cwd
  self._env = {}

  self._is_exited = nil

  self._stdout = nil
  self._stderr = nil

  self._stdout_reader = nil
  self._stderr_reader = nil

  self._stdout_data = nil
  self._stderr_data = nil

  for k, v in pairs(opts.env or {}) do
    assert(type(k) == "string", "expected env var name")
    table.insert(self._env, k .. "=" .. tostring(v))
  end

  return o
end

function Process:_spawn()
  local exe_ok, is_exe = pcall(vim.fn.executable, self._cmd[1])
  assert(exe_ok and is_exe >= 1, "exe not found")

  local uv_opts = {}

  assert(self._cmd and #self._cmd >= 1, "expected command")
  uv_opts.command = self._cmd[1]
  uv_opts.args = { select(2, unpack(self._cmd)) }

  uv_opts.cwd = self._cwd
  uv_opts.env = self._env

  assert(self._stdout, "expected stdout already initialized")
  assert(self._stderr, "expected stderr already initialized")
  uv_opts.stdio = { nil, self._stdout, self._stderr }

  return vim.loop.spawn(uv_opts.command, uv_opts, function(exitcode, signal)
    self:_on_exit(exitcode, signal)
  end)
end

function Process:_reader(f)
  return coroutine.wrap(function(_, data, is_done)
    while data ~= nil and not is_done do
      f(data)
      _, data, is_done = coroutine.yield()
    end
  end)
end

function Process:_execute()
  self._stdout = vim.loop.new_pipe(false)
  self._stderr = vim.loop.new_pipe(false)

  self._handle, self._pid = self:_spawn()

  assert(self._handle, "no handle")
  assert(self._pid and self._pid >= 0, "no _pid (failed to start process?)")

  self._stdout_reader = self:_reader(function(data)
    self._stdout_data = (self._stdout_data or "") .. data
  end)

  self._stderr_reader = self:_reader(function(data)
    self._stderr_data = (self._stderr_data or "") .. data
  end)

  self._stdout:read_start(self._stdout_reader)
  self._stderr:read_start(self._stderr_reader)
end

function Process:_wait(timeout_ms, poll_ms)
  timeout_ms = timeout_ms or 5000
  poll_ms = poll_ms or 10

  vim.wait(timeout_ms, function()
    return self._is_exited
  end, poll_ms, false)
end

function Process:run(timeout_ms)
  self:_execute()
  self:_wait(timeout_ms)
  return self._exitcode, self._stdout_data, self._stderr_data
end

function Process:_on_exit(exitcode, signal)
  assert(not self._is_exited, "cannot exit more than once")

  self._is_exited = true

  self._exitcode = exitcode
  self._signal = signal

  self._stdout:read_stop()
  self._stdout:close()
  self._stdout_reader = nil

  self._stderr:read_stop()
  self._stderr:close()
  self._stderr_reader = nil

  self._handle:close()
  self._handle = nil
end

local function _to_lines(s)
  local lines = {}

  while s and #s > 0 do
    local eol, _ = s:find("\n", 1, true)
    local line = eol and s:sub(1, eol) or s
    s = eol and s:sub(eol + 1) or ""

    line = line:gsub("[%s\r\n]+$", "")
    table.insert(lines, line)
  end

  return lines
end

local function _str_strip(s)
  return s:gsub("^%s+", ""):gsub("%s+$", "")
end

local function _read_file(filename)
  local file = io.open(filename, "r")
  if not file then
    return nil
  end

  local data = file:read("*a")
  file:close()

  return data
end

local function _is_file(filename)
  local f = io.open(filename, "r")
  return f ~= nil and io.close(f)
end

---@return integer? procs number of processors detected
---@nodiscard
function M.cpu_procs()
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

---@param cmd string[] command to run
---@return integer exitcode error code returned by exe
---@return string stdout captured output
---@return string stderr captured error output
function M.run(cmd)
  local proc = Process:new({ cmd = cmd })
  return proc:run()
end

---@return boolean is_win true if current os is windows
---@nodiscard
function M.is_windows()
  return is_windows
end

---@return string? ver_str neovim version string
---@nodiscard
function M.nvim_version()
  local ver_str = vim.fn.execute("version")
  return ver_str:match("^.+ +v([%d.]+)[-_%s]*([%w._-]*)\r?\n")
end

---@package
---@alias regval { type: string, value: number|string }

---@param key string path to registry key
---@return string[] keys, table<string, regval> values, regval? default
---@nodiscard
function M.read_winreg(key)
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

  local _, out, _ = M.run({'reg.exe', 'query', key})
  local lines = _to_lines(out)

  -- skip prelude
  while
    lines
    and #lines > 0
    and lines[1]
    and (lines[1]:match("^[%s\r\n]*$") or lines[1]:match("^[^%s\r\n]"))
  do
    table.remove(lines, 1)
  end

  for _, line in ipairs(lines) do
    if line:match("^%s+") then
      -- line specifies a value
      local name, type_, value = line:match("^%s+(.+)%s+(REG_[%w_]+)%s+(.*)$")
      if name and type_ then
        name = _str_strip(name)
        value = _str_strip(value)

        local entry = { type = type_, value = value }

        if name == "(Default)" then
          default = entry
        else
          values[name] = entry
        end
      end
    elseif line:match("^[^%s]") then
      -- line specifies a sub-key
      local keyname = _str_strip(line)
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
function M.read_winreg_value(key, name)
  if not is_windows then
    return nil
  end

  key = key
    :gsub("[\\/]+", "\\")
    :gsub("[\\/]+$", "")
    :gsub("[^a-zA-Z0-9_\\-\\/\\. ]", "")

  local _, values, default = M.read_winreg(key)

  if not name or #name <= 0 then
    return default
  end

  return values and values[name] or nil
end

local function _get_win_machine_id()
  local key = "HKLM\\SOFTWARE\\Microsoft\\Cryptography"
  local name = "MachineGuid"
  local value = M.read_winreg_value(key, name)
  if not value or not value.value then
    return nil
  end
  return tostring(value.value)
end

local function _get_macos_machine_id()
  local _, output, _ = M.run({"ioreg", "-rd1", "-c", "IOPlatformExpertDevice"})
  if not output then
    return nil
  end
  local match = output:match(
    "IOPlatformUUID[^\n]+=[\r\t\v\n ]*[\"']?(.+)[\"']?[\r\t\v\n ]*$"
  )
  if not match then
    return nil
  end
  return _str_strip(match)
end

local function _get_linux_machine_id()
  local mach_id = _read_file("/var/lib/dbus/machine-id")
  mach_id = mach_id and _str_strip(mach_id) or nil
  if not mach_id or #mach_id <= 0 then
    mach_id = _read_file("/etc-machine-id")
    mach_id = mach_id and _str_strip(mach_id) or nil
  end
  if not mach_id or #mach_id <= 0 then
    return nil
  end
  return mach_id
end

local function _get_bsd_machine_id()
  local mach_id = _read_file("/etc/hostid")
  mach_id = mach_id and _str_strip(mach_id) or nil

  if not mach_id then
    local _, output, _ = M.run({"kenv", "-q", "smbios.system.uuid"})
    mach_id = output and _str_strip(output) or nil
  end

  return mach_id
end

---@return string? mach_id unique machine-specific id
function M.machine_id()
  local mach_id = nil
  if is_windows then
    mach_id = mach_id or _get_win_machine_id()
  else
    mach_id = mach_id
      or _get_macos_machine_id()
      or _get_linux_machine_id()
      or _get_bsd_machine_id()
  end

  return mach_id
end

---@param syspath? string path string or nil to use $PATH env var
---@return string[] path array of dirs found in path
function M.path(syspath)
  syspath = syspath or os.getenv("PATH")

  local dirs = {}

  while syspath and #syspath > 0 do
    local pat = "^%s*(.-)%s*[;:][;:%s]*" -- unix path
    if syspath:match("^%s*[a-zA-Z]:[\\/]") then
      pat = "^%s*([a-zA-Z]:[\\/].-)%s*[;:][;:%s]*" -- win path
    end

    local _, stop, dir = syspath:find(pat)
    if stop then
      syspath = syspath:sub(stop + 1)
    else
      dir = _str_strip(syspath):gsub("[;:%s]+$", "")
      syspath = nil
    end

    if dir and #dir > 0 then
      table.insert(dirs, dir)
    end
  end

  return dirs
end

---@param exe string executable name
---@param syspath? string|string[] $PATH to search. default is use env var
---@return string? filename path to executable if found
function M.in_path(exe, syspath)
  if type(syspath) ~= "table" then
    syspath = M.path(syspath)
  end

  for _, dir in ipairs(syspath) do
    local filename = dir .. path_sep .. exe
    if _is_file(filename) then
      return filename
    elseif is_windows and _is_file(filename .. ".exe") then
      return filename .. ".exe"
    end
  end

  return nil
end

return M
