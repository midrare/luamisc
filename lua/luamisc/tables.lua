local modulename, _ = ...
---@diagnostic disable-next-line: unused-local
local moduleroot = modulename:gsub("(.+)%..+", "%1")

local module = {}

local function is_array(o)
  for key, _ in pairs(o) do
    if type(key) ~= 'number' then
      return false
    end
  end

  return true
end


function module.clone(tbl, deep)
  local target = {}

  for k, v in pairs(tbl) do
    if deep and type(v) == 'table' then
      target[k] = module.clone(v, deep)
    else
      target[k] = v
    end
  end

  local meta = getmetatable(tbl)
  setmetatable(target, not deep and meta or module.clone(meta, deep))

  return target
end


function module.merge(dest, src, opts)
  assert(type(dest) == 'table', 'destination must be a table (array ok)')
  assert(src == nil or type(src) == 'table', 'source must be a table (nil ok)')

  opts = opts or {}

  if src ~= nil then
    if is_array(src) and is_array(dest) then
      for _, value in ipairs(src) do
        if not opts.unique or not vim.tbl_contains(dest, value) then
          table.insert(dest, value)
        end
      end
    else
      for key, value in pairs(src) do
        if type(value) == 'table' and type(dest[key]) == 'table' then
          module.merge(dest[key], value)
        elseif dest[key] == nil or (opts.force == nil or opts.force) then
          dest[key] = value
        end
      end
    end
  end
end


function module.contains(tbl, value)
  if tbl ~= nil then
    for _, v in ipairs(tbl) do
      if v == value then
        return true
      end
    end
  end
  return false
end


function module.is_empty(tbl)
  return next(tbl) == nil
end


function module.make_keys(tbl, ...)
  local current = tbl
  for i = 1, select('#', ...) do
    local key = select(i, ...)
    if current[key] == nil then
      current[key] = {}
    end
    current = current[key]
  end
end


function module.has_keys(tbl, ...)
  if tbl == nil then
    return false
  end

  local current = tbl
  for i = 1, select('#', ...) do
    local key = select(i, ...)
    if current[key] == nil then
      return false
    end
    current = current[key]
  end

  return true
end


local function overwrite(src, target)
  for k, v in pairs(src) do
    if type(v) == 'table' then
      target[k] = {}
      overwrite(v, target[k])
    else
      target[k] = v
    end
  end
end


function module.overwrite(src, target)
  for k, _ in pairs(target) do
    target[k] = nil
  end
  overwrite(src, target)
end


function module.tostring(o)
  local type_ = type(o)
  if type_ == 'string' then
    return '"' .. tostring(o) .. '"'
  elseif type_ ~= 'table' then
    return tostring(o)
  end

  local is_first = true
  local is_array_ = is_array(o)

  local result = is_array_ and '[' or '{'
  for key, value in pairs(o) do
    if not is_first then
      result = result .. ', '
    end

    if not is_array_ then
      if type(key) == 'string' and key:find('%s') then
        result = result .. '"' .. key .. '"' .. ': '
      else
        result = result .. tostring(key) .. ': '
      end
    end

    result = result .. module.tostring(value)
    is_first = false
  end

  return result .. (is_array_ and ']' or '}')
end

return module
