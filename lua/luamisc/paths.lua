local modulename, _ = ...
---@diagnostic disable-next-line: unused-local
local moduleroot = modulename:gsub("(.+)%..+", "%1")

local module = {}

local is_windows = vim.fn.has('win32') > 0
local path_sep = vim.fn.has('win32') > 0 and '\\' or '/'


---@return string sep os-specific path separator
---@nodiscard
function module.sep()
  return path_sep
end

---@param filename string file path
---@return string? basename last component of file path
---@nodiscard
function module.basename(filename)
  local bname, _ = filename:gsub('^.*[\\/](.+)[\\/]*', '%1')
  if not bname or #bname <= 0 then
    return nil
  end
  return bname
end

---@param filename string file path
---@return string? dir parent directory of path
---@nodiscard
function module.dirname(filename)
  local parent_dir = filename:match('^(.*[\\/]).+$')
  if not parent_dir or #parent_dir <= 0 then
    return nil
  end
  return parent_dir:match('^(.+)[\\/]+$') or parent_dir
end

---@param filename string file path
---@return string? stem base name without file extension
---@nodiscard
function module.filestem(filename)
  local basename = filename:match('^.+[\\/](.+)$') or filename
  local stem = basename:gsub('^(.+)%.[^%s]+$', '%1')
  if not stem or #stem <= 0 then
    return nil
  end
  return stem
end

---@param filename string file path
---@return string? file extension if any
---@nodiscard
function module.fileext(filename)
  local basename = filename:match('^.+[\\/](.+)$') or filename
  local ext = basename:match('^.+(%.[^%s]+)$')
  if not ext or #ext <= 0 then
    return nil
  end
end

---@param filename string file path
---@return string filepath file path with path separators for current os
---@nodiscard
function module.normcase(filename)
  local p, _ = nil, nil
  if is_windows then
    p, _ = filename:gsub('/', '\\')
  else
    p, _ = filename:gsub('\\', '/')
  end
  return p
end

---@param filename string file path
---@return string filepath file path with ".." collapsed
---@nodiscard
function module.normpath(filename)
  if is_windows then
    if filename:match('^\\\\') then -- UNC
      return '\\\\' .. module.normpath(filename:sub(3))
    end
    filename = filename:gsub('/', '\\')
  end

  local num_subs = 0
  repeat
    -- // to /
    filename, num_subs = filename:gsub('[\\/][\\/]+', path_sep)
  until num_subs <= 0

  repeat
    -- /./ to /
    filename, num_subs = filename:gsub('[\\/]%.[\\/]', path_sep)
  until num_subs <= 0

  repeat
    -- foo/.. to ""
    filename, num_subs = filename:gsub('[^\\/]+[\\/]%.%.[\\/]*', '')
  until num_subs <= 0

  if filename == '' then
    filename = '.'
  end

  -- foo/bar/ to foo/bar
  filename = filename:gsub('[\\/]+$', '')

  -- C: to C:\
  if is_windows and filename:match('^[^\\/]+:$') then
    filename = filename .. '\\'
  end

  return filename
end

---@param filename string file path
---@return boolean is_abs if file path is an absolute path
---@nodiscard
function module.isabs(filename)
  return filename:match('^[\\/]') or filename:match('^[a-zA-Z]:[\\/]')
end

---@param filename string file path
---@param pwd string current directory
---@return string filename absolute file path
---@nodiscard
function module.abspath(filename, pwd)
  filename = filename:gsub('[\\/]+$', '')
  if not module.isabs(filename) then
    filename = pwd:gsub('[\\/]+$', '') .. path_sep .. filename
  end
  return module.normpath(filename)
end

---@param filename string file path
---@param cwd string current directory
---@return string filename canonical file path
---@nodiscard
function module.canonical(filename, cwd)
  local normcased = module.normcase(filename)

  if not module.isabs(normcased) then
    return module.abspath(normcased, cwd)
  end

  return normcased
end

---@vararg string file path segments
---@return string filepath file path joined using os-specific path separator
---@nodiscard
function module.join(...)
  local sep = module.sep()
  local joined = ''

  for i = 1, select('#', ...) do
    local el = select(i, ...):gsub('[\\/]+$', '')
    if el and #el > 0 then
      if #joined > 0 then
        joined = joined .. sep
      end
      joined = joined .. el
    end
  end

  return joined
end

return module
