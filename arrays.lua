local M = {}

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

function M.is_array(o)
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
function M.get_from(items, start, stop)
  start, stop = _to_norm_range(items, start, stop)
  local results = {}
  _do_from(items, function(e)
    table.insert(results, e)
  end, start, stop)
  return results
end

---@param items any[] items to extract from
---@param pred? fun(any): boolean true if should extract
---@param invert? boolean switch behavior of predicate
---@return any[] items all items satisfying the predicate
---@nodiscard
function M.get_if(items, pred, invert)
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
function M.remove_from(items, start, stop)
  start, stop = _to_norm_range(items, start, stop)
  local results = {}
  _del_from(items, function(e)
    table.insert(results, e)
  end, start, stop)
  return results
end

---@param items any[] items to extract from
---@param pred? fun(any): boolean true if should extract
---@param invert? boolean switch behavior of predicate
---@return any[] items all items satisfying the predicate
function M.remove_if(items, pred, invert)
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
function M.clone(items, start, stop, deep)
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
---@param key? fun(any): any how to compare for equivalence
function M.uniqify(items, key)
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
      base = base + 1
    end
  end

  for i = base + 1, #items do
    items[i] = nil
  end
end

---@param items any[] array to extend
---@param more any[] items to append
function M.extend(items, more)
  for _, e in ipairs(more) do
    table.insert(items, e)
  end
end

---@param items any[] list to iterate over
---@param f fun(any) function to apply
---@param start? integer index to start at
---@param stop? integer index to stop at (inclusive)
function M.apply(items, f, start, stop)
  start, stop = _to_norm_range(items, start, stop)
  _do_from(items, f, start, stop)
end

---@param items any[] items to filter
---@param pred? fun(any): boolean true if should keep
---@param invert? boolean switch behavior of predicate
function M.filter(items, pred, invert)
  invert = invert or false
  M.remove_if(items, pred, not invert)
end

---@param items? any[] items to transform
---@param f? fun(a: any): any transformation to apply
function M.transform(items, f)
  if items == nil or f == nil then
    return
  end
  local idx = 1
  for i = 1, #items do
    local value = f(items[i])
    if value ~= nil then
      items[idx] = value
      idx = idx + 1
    end
  end
end

---@param items any[] items to remove from
---@param value any value to remove
---@param invert? boolean true to reverse behavior
function M.remove(items, value, invert)
  _del_if(items, nil, function(o)
    return o == value
  end, invert)
end

---@param items any[] items to reorder as an array
function M.canonicalize(items)
  local keys = {}
  for k, _ in pairs(items) do
    table.insert(keys, k)
  end
  table.sort(keys)

  local old = {}
  local base = 1
  for _, key in ipairs(keys) do
    old[base] = items[base]

    if old[key] ~= nil then
      items[base] = old[key]
    else
      items[base] = items[key]
    end

    base = base + 1
  end
end

---@vararg ... elements to pack
---@return any[] items elements packed into array
function M.pack(...)
  local a = {}
  for i = 1, select("#", ...) do
    local val = select(i, ...)
    -- nil breaks ipairs() so we ignore
    if val ~= nil then
      table.insert(a, val)
    end
  end
  return a
end

---@param items any[] array to iterate over
---@param f (fun(any, any): any)? how to accumulate
---@param initial any? initial accumulator value
---@return any acc resultant value
function M.reduce(items, f, initial)
  if initial == nil then
    initial = items[1]
  end
  f = f or function(e, acc) return acc + e end

  local accumulator = initial
  for _, e in ipairs(items) do
    accumulator = f(e, accumulator)
  end
  return accumulator
end

return M
