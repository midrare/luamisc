local M = {}

local vimfn = (vim or {}).fn or {}

local is_windows = (function()
  local is_ok, has_win = pcall(vimfn.has, "win32")
  if is_ok then
    return has_win > 0
  end
  return package.config:sub(1, 1) == "\\"
end)()
local path_sep = is_windows and "\\" or "/"

local function get_cwd()
  local cwd = vimfn.getcwd and vimfn.getcwd(-1, -1) or nil
  if cwd then
    cwd = cwd:gsub("[\\/]+$", ""):gsub("[\\/]", "/")
    return cwd
  end

  local pwd_cmd = is_windows and "echo %cd%" or "pwd"
  local pipe = io.popen(pwd_cmd)
  cwd = pipe and pipe:read("*l")
  if pipe then
    pipe:close()
  end

  cwd = cwd:gsub("[\\/]+$", ""):gsub("[\\/]", "/")
  return cwd
end

local function split_path(s)
  local parts = {}
  s:gsub("[^\\/]+", function(e)
    table.insert(parts, e)
  end)
  return parts
end

---@return string sep os-specific path separator
---@nodiscard
function M.sep()
  return path_sep
end

---@param filename string file path
---@return string basename last component of file path
---@nodiscard
function M.basename(filename)
  local bname, _ = filename:gsub("^.*[\\/](.+)[\\/]*", "%1")
  return bname
end

---@param filename string file path
---@return string? dir parent directory of path
---@nodiscard
function M.dirname(filename)
  local parent_dir = filename:match("^(.*[\\/]).+$")
  if not parent_dir or #parent_dir <= 0 then
    return nil
  end
  return parent_dir:match("^(.+)[\\/]+$") or parent_dir
end

---@param filename string file path
---@return string? stem base name without file extension
---@nodiscard
function M.filestem(filename)
  local basename = filename:match("^.+[\\/](.+)$") or filename
  local stem = basename:gsub("^(.+)%.[^%s]+$", "%1")
  if not stem or #stem <= 0 then
    return nil
  end
  return stem
end

---@param filename string file path
---@return string? file extension if any
---@nodiscard
function M.fileext(filename)
  local basename = filename:match("^.+[\\/](.+)$") or filename
  local ext = basename:match("^.+(%.[^%s]+)$")
  if not ext or #ext <= 0 then
    return nil
  end
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

---@param filename string file path
---@return string filepath file path with ".." collapsed
---@nodiscard
function M.normpath(filename)
  if is_windows then
    if filename:match("^\\\\") then -- UNC
      return "\\\\" .. M.normpath(filename:sub(3))
    end
    filename = filename:gsub("/", "\\")
  end

  local num_subs = 0
  repeat
    -- // to /
    filename, num_subs = filename:gsub("[\\/][\\/]+", path_sep)
  until num_subs <= 0

  repeat
    -- /./ to /
    filename, num_subs = filename:gsub("[\\/]%.[\\/]", path_sep)
  until num_subs <= 0

  repeat
    -- foo/.. to ""
    filename, num_subs = filename:gsub("[^\\/]+[\\/]%.%.[\\/]*", "")
  until num_subs <= 0

  if filename == "" then
    filename = "."
  end

  -- foo/bar/ to foo/bar
  filename = filename:gsub("[\\/]+$", "")

  -- C: to C:\
  if is_windows and filename:match("^[^\\/]+:$") then
    filename = filename .. "\\"
  end

  return filename
end

---@param filename string file path
---@return boolean is_abs if file path is an absolute path
---@nodiscard
function M.isabs(filename)
  return filename:match("^[\\/]") or filename:match("^[a-zA-Z]:[\\/]")
end

---@param filename string file path
---@param cwd? string current directory
---@return string filename absolute file path
---@nodiscard
function M.abspath(filename, cwd)
  cwd = cwd or get_cwd()
  filename = filename:gsub("[\\/]+$", "")
  if not M.isabs(filename) then
    filename = cwd:gsub("[\\/]+$", "") .. path_sep .. filename
  end
  return M.normpath(filename)
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
---@return string filepath file path joined using os-specific path separator
---@nodiscard
function M.join(...)
  local sep = M.sep()
  local joined = ""

  for i = 1, select("#", ...) do
    local el = select(i, ...):gsub("[\\/]+$", "")
    if el and #el > 0 then
      if #joined > 0 then
        joined = joined .. sep
      end
      joined = joined .. el
    end
  end

  return joined
end

---@param filename string file path to make relative
---@param origin? string dir to make relative against
---@param inscase? boolean true if ignore case
---@return string relpath
function M.relpath(filename, origin, inscase)
  if inscase == nil then
    inscase = is_windows
  end
  origin = origin or get_cwd()
  origin = M.normcase(origin)
  filename = M.abspath(filename, origin)

  local origin_segs = split_path(origin)
  local path_segs = split_path(filename)

  local mismatch_idx = math.min(#origin_segs, #path_segs) + 1
  for i = 1, math.min(#origin_segs, #path_segs) do
    if
      (not inscase and origin_segs[i] ~= path_segs[i])
      or (inscase and origin_segs[i]:lower() ~= path_segs[i]:lower())
    then
      mismatch_idx = i
      break
    end
  end

  local components = {}
  ---@diagnostic disable-next-line: unused-local
  for i = 1, #origin_segs - mismatch_idx + 1 do
    table.insert(components, "..")
  end

  for i = mismatch_idx, #path_segs do
    table.insert(components, path_segs[i])
  end

  return table.concat(components, path_sep)
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
