local M = {}

local function is_array(o)
  for key, _ in pairs(o) do
    if type(key) ~= "number" then
      return false
    end
  end

  return true
end

local function array_contains(arr, value)
  for _, val in pairs(arr) do
    if val == value then
      return true
    end
  end
  return false
end

function M.clone(tbl, deep)
  local target = {}

  for k, v in pairs(tbl) do
    if deep and type(v) == "table" then
      target[k] = M.clone(v, deep)
    else
      target[k] = v
    end
  end

  local meta = getmetatable(tbl)
  setmetatable(target, not deep and meta or M.clone(meta, deep))

  return target
end

function M.merge(src, dest, opts)
  assert(type(dest) == "table", "destination must be a table (array ok)")
  assert(src == nil or type(src) == "table", "source must be a table (nil ok)")

  opts = opts or {}

  if src ~= nil then
    if is_array(src) and is_array(dest) then
      if opts.unique then
        local seen = {}
        for _, value in ipairs(dest) do
          seen[value] = true
        end
        for _, value in ipairs(src) do
          if not seen[value] then
            table.insert(dest, value)
            seen[value] = true
          end
        end
      else
        for _, value in ipairs(src) do
          table.insert(dest, value)
        end
      end
    else
      for key, value in pairs(src) do
        if type(value) == "table" and type(dest[key]) == "table" then
          M.merge(value, dest[key])
        elseif dest[key] == nil or (opts.force == nil or opts.force) then
          dest[key] = value
        end
      end
    end
  end
end

function M.contains(tbl, value)
  if tbl ~= nil then
    for _, v in ipairs(tbl) do
      if v == value then
        return true
      end
    end
  end
  return false
end

function M.is_empty(tbl)
  return next(tbl) == nil
end

function M.make_keys(tbl, ...)
  local current = tbl
  for i = 1, select("#", ...) do
    local key = select(i, ...)
    if current[key] == nil then
      current[key] = {}
    end
    current = current[key]
  end
end

function M.has_keys(tbl, ...)
  if tbl == nil then
    return false
  end

  local current = tbl
  for i = 1, select("#", ...) do
    local key = select(i, ...)
    if current[key] == nil then
      return false
    end
    current = current[key]
  end

  return true
end

---@param items? any[] items to transform
---@param f? fun(a: any): any transformation to apply
function M.transform(items, f)
  if items == nil or f == nil then
    return
  end
  for k, v in pairs(items) do
    items[k] = f(v)
  end
end

local function overwrite(src, target)
  for k, v in pairs(src) do
    if type(v) == "table" then
      target[k] = {}
      overwrite(v, target[k])
    else
      target[k] = v
    end
  end
end

function M.overwrite(src, target)
  for k, _ in pairs(target) do
    target[k] = nil
  end
  overwrite(src, target)
end

local function _flat_append(dest, key, value)
  if type(value) == "table" then
    local keys = {}

    for k, _ in pairs(value) do
      table.insert(keys, k)
    end

    table.sort(keys)
    for _, k in ipairs(keys) do
      _flat_append(dest, k, value[k])
    end
  elseif key and type(key) ~= "number" then
    dest[key] = value
  elseif value ~= nil then
    table.insert(dest, value)
  end
end

function M.flattened(...)
  local o = {}
  for i = 1, select("#", ...) do
    local val = select(i, ...)
    table.insert(o, val)
  end

  local flat = {}
  _flat_append(flat, nil, o)
  return flat
end

function M.tostring(o)
  local type_ = type(o)
  if type_ == "string" then
    return '"' .. tostring(o) .. '"'
  elseif type_ ~= "table" then
    return tostring(o)
  end

  local is_first = true
  local is_array_ = is_array(o)

  local result = is_array_ and "[" or "{"
  for key, value in pairs(o) do
    if not is_first then
      result = result .. ", "
    end

    if not is_array_ then
      if type(key) == "string" and key:find("%s") then
        result = result .. '"' .. key .. '"' .. ": "
      else
        result = result .. tostring(key) .. ": "
      end
    end

    result = result .. M.tostring(value)
    is_first = false
  end

  return result .. (is_array_ and "]" or "}")
end

return M
