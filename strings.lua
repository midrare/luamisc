local M = {}

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
  while (n > 0) do
    local idx = n % #charset
    s = charset:sub(idx, idx) .. s
    n = math.floor(n / #charset)
  end

  return s
end

return M