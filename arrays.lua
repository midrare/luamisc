local modulename, _ = ...
---@diagnostic disable-next-line: unused-local
local moduleroot = modulename:gsub("(.+)%..+", "%1")

local module = {}

local function pred_default(a)
  if a then
    return true
  end
  return false
end


local function _to_norm_range(arr, start, stop)
  if not start then
    start = 1
  elseif start < 0 then
    start = #arr + start + 1
  end
  start = math.max(1, start)

  if not stop then
    stop = #arr
  elseif stop < 0 then
    stop = #arr + stop + 1
  end
  stop = math.min(#arr, stop)

  return start, stop
end

local function _del_from(arr, f, start, stop)
  assert(start <= stop)

  local base = start
  for i = stop + 1, #arr do
    local e = arr[i]
    if f then
      f(e)
    end
    arr[i] = nil
    arr[base] = e
    base = base + 1
  end

  for i = base, #arr do
    arr[i] = nil
  end
end

local function _do_from(items, f, start, stop)
  if (start <= 0 and stop <= 0) or (start > #items and stop > #items) then
    return
  end

  if start <= stop then
    start = math.max(1, start)
  else
    start = math.min(#items, start)
  end

  local inc = start <= stop and 1 or -1

  for i = start, stop, inc do
    local e = items[i]
    if e == nil then
      break
    end
    f(items[i])
  end
end

local function _del_if(items, f, pred, invert)
  local base = 1
  -- int-based iteration is important! its not safe in lua
  -- to mutate while iterating using pairs() or ipairs()
  for i = 1, #items do
    local item = items[i]
    items[i] = nil
    local is_match = pred(item)
    if (not invert and is_match) or (invert and not is_match) then
      if f then
        f(item)
      end
    else
      items[base] = item
      base = base + 1
    end
  end
end

local function _do_if(items, f, pred, invert)
  for _, item in ipairs(items) do
    local is_match = pred(item)
    if (not invert and is_match) or (invert and not is_match) then
      f(item)
    end
  end
end

local function _cloned(o, deep)
  deep = deep or false
  local o2 = o

  if type(o) == "table" then
    o2 = {}
    for k, v in pairs(o) do
      if deep then
        o2[k] = _cloned(v, deep)
      else
        o2[k] = v
      end
    end
  end

  local meta = getmetatable(o)
  if deep then
    meta = _cloned(meta, deep)
  end
  setmetatable(o2, meta)

  return o2
end


function module.is_array(o)
  if type(o) ~= "table" then
    return false
  end
  local max_idx = 0
  for i, _ in pairs(o) do
    max_idx = i
  end
  return max_idx == #o
end


---@param items any[] array to read from
---@param start? integer start index
---@param stop? integer stop index (inclusive)
---@return any[] got results within range
---@nodiscard
function module.get_from(items, start, stop)
  start, stop = _to_norm_range(items, start, stop)
  local results = {}
  _do_from(items, function(e)
    table.insert(results, e)
  end, start, stop)
  return results
end


---@param items any[] items to extract from
---@param pred? function(any): boolean true if should extract
---@param invert? boolean switch behavior of predicate
---@return any[] items all items satisfying the predicate
---@nodiscard
function module.get_if(items, pred, invert)
  pred = pred or pred_default
  invert = invert or false
  local results = {}
  _do_if(items, function(e)
    table.insert(results, e)
  end, pred, invert)
  return results
end


---@param items any[] items to extract from
---@param start? integer start index
---@param stop? integer stop index (inclusive)
---@return any[] extracted items extracted within range
function module.remove_from(items, start, stop)
  start, stop = _to_norm_range(items, start, stop)
  local results = {}
  _del_from(items, function(e)
    table.insert(results, e)
  end, start, stop)
  return results
end


---@param items any[] items to extract from
---@param pred? function(any): boolean true if should extract
---@param invert? boolean switch behavior of predicate
---@return any[] items all items satisfying the predicate
function module.remove_if(items, pred, invert)
  pred = pred or pred_default
  invert = invert or false
  local results = {}
  _del_if(items, function(e)
    table.insert(results, e)
  end, pred, invert)
  return results
end


---@param items any[] array to clone
---@param start? integer start index
---@param stop? integer stop index (inclusive)
---@param deep? boolean do deep clone
---@return any[] clone cloned items
---@nodiscard
function module.clone(items, start, stop, deep)
  start, stop = _to_norm_range(items, start, stop)
  local results = {}
  _do_from(items, function(e)
    if deep then
      e = _cloned(e, deep)
    end
    table.insert(results, e)
  end, start, stop)
  return results
end


---@param items any[] array to make unique
---@param key? function(any): any how to compare for equivalence
function module.uniqify(items, key)
  local seen = {}
  local base = 1

  -- int-based iteration is important! its not safe in lua to
  -- mutate while iterating using pairs() or ipairs()
  for i = 1, #items do
    local e = items[i]
    items[i] = nil

    local k = e
    if key then
      k = key(e)
    end

    if not seen[k] then
      seen[k] = true
      items[base] = e
      base = i + 1
    end
  end

  for i = base + 1, #items do
    items[i] = nil
  end
end


---@param items any[] array to extend
---@param more any[] items to append
function module.extend(items, more)
  for _, e in ipairs(more) do
    table.insert(items, e)
  end
end


---@param items any[] list to iterate over
---@param f function(any) function to apply
---@param start? integer index to start at
---@param stop? integer index to stop at (inclusive)
function module.apply(items, f, start, stop)
  start, stop = _to_norm_range(items, start, stop)
  _do_from(items, f, start, stop)
end


---@param items any[] items to filter
---@param pred? function(any): boolean true if should keep
---@param invert? boolean switch behavior of predicate
function module.filter(items, pred, invert)
  invert = invert or false
  module.remove_if(items, pred, not invert)
end


---@param items any[] items to transform
---@param f function(a: any): any transformation to apply
function module.transform(items, f)
  for k, v in pairs(items) do
    items[k] = f(v)
  end
end


---@param items any[] items to remove from
---@param value any value to remove
---@param invert? boolean true to reverse behavior
function module.remove(items, value, invert)
  _del_if(items, nil, function(o)
    return o == value
  end, invert)
end


return module
