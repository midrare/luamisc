local M = {}

local is_windows = vim.fn.has("win32") >= 1
local path_sep = vim.fn.has("win32") >= 1 and "\\" or "/"

local function get_cwd()
  return vim.fn.getcwd(-1, -1):gsub("[\\/]+$", ""):gsub("[\\/]", "/")
end

local function split_path(s)
  local parts = {}
  local seps = {}

  local m = s:match("^[\\/]+")
  if m then
    table.insert(parts, "")
    table.insert(seps, m)
  end

  s:gsub("([^\\/]+)([\\/]*)", function(a, b)
    table.insert(parts, a)
    table.insert(seps, b)
  end)

  return parts, seps
end

---@return string sep os-specific path separator
---@nodiscard
function M.sep()
  return path_sep
end

---@param path string file path
---@return string basename last component of file path
---@nodiscard
function M.basename(path)
  if path:match("^%a:[\\/]+$") or path:match("^%.*[\\/]+$") then
    return path
  end

  local path_ = path:gsub("[\\/]+$", "")
  local bname, _ = path_:gsub("^.*[\\/](.+)", "%1")
  return bname
end

---@param path string file path
---@return string dir parent directory of path
---@nodiscard
function M.dirname(path)
  if path:match("^%a:[\\/]+$") or path:match("^%.*[\\/]*$") then
    return path
  end

  local dir_, _ = path:gsub("[\\/]+$", ""):gsub("[^\\/]+$", "")

  if dir_:match("^%a:[\\/]+$") or dir_:match("^%.*[\\/]*$") then
    return dir_
  end

  dir_, _ =  dir_:gsub("[\\/]+$", "")
  return dir_
end

---@param filename string file path
---@return string? stem base name without file extension
---@nodiscard
function M.filestem(filename)
  local basename = M.basename(filename)
  local stem = basename:gsub("^(.+)%.[^%s]+$", "%1")
  if not stem or #stem <= 0 then
    return nil
  end
  return stem
end

---@param path string a file or dir path
---@return string[] parents all parent directories
function M.parents(path)
  local parents = {}

  local path_ = path
  while path_ and #path_ > 0 do
    local parent = M.dirname(path_)
    if not parent or parent == path_ or #parent <= 0 then
      break
    end
    table.insert(parents, parent)
    path_ = parent
  end

  return parents
end

---@param filename string file path
---@return string? file extension if any
---@nodiscard
function M.fileext(filename)
  local basename = M.basename(filename)
  local ext, _ = basename:match("[^%.\\/](%.[^%s%.\\/]+)$")
  if not ext or #ext <= 0 then
    return nil
  end
  return ext
end

---@param filename string file path
---@return string filepath file path with path separators for current os
---@nodiscard
function M.normcase(filename)
  local p, _ = nil, nil
  if is_windows then
    p, _ = filename:gsub("/", "\\")
  else
    p, _ = filename:gsub("\\", "/")
  end
  return p
end

---@param path string file path
---@return string norm file path with ".." collapsed
---@nodiscard
function M.normpath(path)
  if is_windows then
    if path:match("^\\\\") then -- UNC
      return "\\\\" .. M.normpath(path:sub(3))
    end
  end

  local num_subs = 0
  repeat
    -- // to /
    path, num_subs = path:gsub("([\\/])[\\/]+", "%1")
  until num_subs <= 0

  repeat
    -- /./ to /
    path, num_subs = path:gsub("([\\/])%.[\\/]", "%1")
  until num_subs <= 0

  repeat
    -- foo/.. to ""
    path, num_subs = path:gsub("[^\\/]+[\\/]%.%.[\\/]*", "")
  until num_subs <= 0

  if path == "" then
    path = "."
  end

  path = path:gsub("([\\/])[\\/]+", "%1")

  if path:match("^%a:[\\/]+$") or path:match("^%.*[\\/]+$") then
    return path
  end

  -- foo/bar/ to foo/bar
  path = path:gsub("[\\/]+$", "")

  return path
end

---@param path string file path
---@return boolean is_abs if file path is an absolute path
---@nodiscard
function M.isabs(path)
  local m = path:match("^[\\/]") or path:match("^%a:[\\/]")
  return m ~= nil
end

---@param path string file path
---@param cwd? string current directory
---@return string absp absolute file path
---@nodiscard
function M.abspath(path, cwd)
  cwd = cwd or get_cwd()
  path = path:gsub("[\\/]+$", "")
  if not M.isabs(path) then
    local sep = cwd:match("[\\/]") or path:match("[\\/]") or path_sep
    path = cwd:gsub("[\\/]+$", "") .. sep .. path
  end
  return M.normpath(path)
end

---@param filename string file path
---@param cwd? string current directory
---@return string filename canonical file path
---@nodiscard
function M.canonical(filename, cwd)
  local normcased = M.normcase(filename)

  if not M.isabs(normcased) then
    return M.abspath(normcased, cwd)
  end

  return normcased
end

---@vararg string file path segments
---@return string path file path joined using os-specific path separator
---@nodiscard
function M.join(...)
  local joined = ""

  for i = 1, select("#", ...) do
    local el = select(i, ...)

    if el and #el > 0 then
      if #joined > 0 then
        local sep = nil

        -- find path sep scanning backwards from current element
        if not sep and i > 1 then
          for j = (i - 1), 1, -1 do
            local s = select(j, ...)

            for q = #s, 1, -1 do
              local ch = s:sub(q, q)
              if ch == "\\" or ch == "/" then
                sep = ch
                break
              end
            end

            if sep then
              break
            end
          end
        end

        -- find path sep scanning forward from current element
        if not sep then
          for j = i, select('#', ...) do
            local s = select(j, ...)
            local q, p = s:find("[\\/]")
            if q and p then
              sep = s:sub(q, p)
              break
            end
          end
        end

        joined = joined .. (sep or path_sep)
      end
      if #joined > 0 then
        el = el:gsub("^[\\/]+", "")
      end
      joined = joined .. el:gsub("[\\/]+$", "")
    end
  end

  return joined
end

---@param path string file path to make relative
---@param origin? string dir to make relative against
---@param icase? boolean true if ignore case
---@return string relpath relative path
function M.relpath(path, origin, icase)
  if icase == nil then
    icase = is_windows
  end
  origin = origin or get_cwd()
  origin = M.normcase(origin)
  path = M.abspath(path, origin)

  local origin_parts, origin_seps = split_path(origin)
  local path_parts, path_seps = split_path(path)

  local mismatch_idx = math.min(#origin_parts, #path_parts) + 1
  for i = 1, math.min(#origin_parts, #path_parts) do
    if
      (not icase and origin_parts[i] ~= path_parts[i])
      or (icase and origin_parts[i]:lower() ~= path_parts[i]:lower())
    then
      mismatch_idx = i
      break
    end
  end

  local sep = nil
  if not sep then
    for i = 1, #path_seps do
      if #path_seps[i] > 0 then
        sep = path_seps[i]
        break
      end
    end
  end
  if not sep then
    for i = #origin_seps, 1, -1 do
      if #origin_seps[i] > 0 then
        sep = origin_seps[i]
        break
      end
    end
  end
  sep = sep or path_sep

  local joined = ""
  ---@diagnostic disable-next-line: unused-local
  for i = 1, #origin_parts - mismatch_idx + 1 do
    if #joined > 0 then
      joined = joined .. sep
    end
    joined = joined .. ".."
  end

  for i = mismatch_idx, #path_parts do
    if #joined > 0 then
      joined = joined .. (path_seps[i-1] or sep)
    end
    joined = joined .. path_parts[i]
  end

  return joined
end

---@param ext string? file extension
---@return string? ext canonicalized file extension
function M.canonical_ext(ext)
  if not ext then
    return nil
  end
  ext = ext:gsub("^[%s%.]+", ""):gsub("%s+$", "")
  if #ext <= 0 then
    return nil
  end
  return "." .. ext:lower()
end

return M
