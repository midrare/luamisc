local module, _ = {}, nil
module.name, _ = ...

local function dirname(filename)
  local d = filename:match('^(.*[\\/]).+$')
  if d ~= nil then
    d = d:match('^(.+)[\\/]+$') or d
  end
  return d
end


local function fix_numeric_keys(o)
  if type(o) ~= "table" then
    return o
  end

  local remapped = {}

  for key, value in pairs(o) do
    if type(key) == 'string' then
      key = tonumber(key) or key
    end

    if type(value) == 'table' then
      value = fix_numeric_keys(value)
    end

    remapped[key] = value
  end

  return remapped
end


---@param filename string path to file
---@return any? data file contents
---@nodiscard
function module.read_file(filename)
  local file = io.open(filename, 'r')
  if not file then
    return nil
  end

  local data = file:read('*a')
  file:close()

  return data
end

---@param filename string path to file
---@param data? any data to write
---@return boolean status true if write ok
function module.write_file(filename, data)
  if data == nil then
    data = ''
  end

  local parent_dir = dirname(filename)
  if parent_dir then
    vim.fn.mkdir(parent_dir, 'p')
  end

  local fd = vim.loop.fs_open(filename, 'w', 438)
  if not fd then
    return false
  end

  local ret = vim.loop.fs_write(fd, data)
  vim.loop.fs_close(fd)

  return type(ret) == "number" and ret >= 0
end

---@param filename string path to json file
---@return any? data parsed file contents
---@nodiscard
function module.read_json(filename)
  if vim.fn.filereadable(filename) <= 0 then
    return nil
  end

  local data = module.read_file(filename)
  if not data then
    return nil
  end

  local status_ok, obj = pcall(vim.fn.json_decode, data)
  if not status_ok or not obj then
    return nil
  end

  return fix_numeric_keys(obj)
end

---@param filename string path to json file
---@param data? any data to encode as json and write
function module.write_json(filename, data)
  assert(type(filename) == 'string', 'filepath must be of type string')
  local status_ok, json = pcall(vim.fn.json_encode, data)
  if not status_ok or not json then
    return
  end
  module.write_file(filename, json)
end

return module
