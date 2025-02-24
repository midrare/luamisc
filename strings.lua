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

local utf8 = utf8 or nil
if not utf8 then
  local old_package_path = package.path
  package.path = get_script_dir() .. "/?.lua"
  utf8 = require("utf8")
  package.path = old_package_path
end


local alnum = "abcdefghijklmnopqrstuvwxyz"
  .. "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
  .. "1234567890"

---@param len integer string length
---@param charset? string character set to use
---@return string random generated string
function M.random(len, charset)
  charset = charset or alnum
  len = len or 16

  local result = ""
  ---@diagnostic disable-next-line: unused-local
  for i = 1, len do
    local ch_idx = math.random(1, #charset)
    result = result .. charset:sub(ch_idx, ch_idx)
  end
  return result
end

function M.strip(s)
  return s:gsub("^[%s]+", ""):gsub("[%s]+$", "")
end

---@param n integer number to convert
---@param charset? string character set to use
---@return string string converted string
function M.itoa(n, charset)
  charset = charset or alnum
  assert(n >= 0, "expected zero or greater")
  assert(math.floor(n) == n, "expected integer")
  if n == 0 then
    return charset:sub(1, 1)
  end

  local s = ""
  while n > 0 do
    local idx = n % #charset
    s = charset:sub(idx, idx) .. s
    n = math.floor(n / #charset)
  end

  return s
end

---@param s string string to split by newline
---@param strip? boolean true to remove surrounding whitespace
---@param blank? boolean false to disallow whitespace-only lines
---@return string[] lines array of lines
function M.lines(s, strip, blank)
  strip = strip or false
  blank = blank ~= false
  local lines = {}

  while s and #s > 0 do
    local eol, _ = s:find("\n", 1, true)
    local line = eol and s:sub(1, eol) or s
    s = eol and s:sub(eol + 1) or ""

    line = line:gsub("\r$", "")
    if strip then
      line = line:gsub("^%s+", ""):gsub("%s+$", "")
    end

    if blank or not line:match("^%s*$") then
      table.insert(lines, line)
    end
  end

  return lines
end

---@param s string utf-8 string
---@param i integer substring start
---@param j integer? substring end
function M.sub(s, i, j)
  assert(s ~= nil, "expected string")
  assert(i ~= nil, "expected start index")

  local start_ok, start = pcall(utf8.offset, s, i)
  if not start_ok or not start then
    -- out of bounds
    start = #s + 1
    if i < 0 then
      start = start * -1
    end
  end

  local stop_ok, stop = nil, nil
  if j ~= nil then
    stop_ok, stop = pcall(utf8.offset, s, j)
    if not stop_ok or not stop then
      -- out of bounds
      ---@diagnostic disable-next-line: cast-local-type
      stop = #s + 1
      if j < 0 then
        stop = stop * -1
      end
    end
  end

  return s:sub(start, stop)
end

---@param s string string to measure
---@return integer len string length
function M.len(s)
  return utf8.len(s) or 0
end

return M
