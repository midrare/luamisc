local require = (function()
  local d = (function()
    local cwd=((vim and vim.loop and vim.loop.cwd())
      or io.popen((package.config:sub(1,1)=='/'and'pwd'or'echo %cd%')):read'*l')
      :gsub('[\\/]+$',''):gsub('[\\/]','/')
    local p=(debug.getinfo(1).source):gsub('^@',''):match('.*[\\/]') or ''
    if p:match('^%a:[\\/]') or p:match('^[\\/]') then return p end
    return cwd..'/'..p
  end)()
  local require_ = require
  return function(m, opts)
    opts = opts or {}; if opts.force then package.loaded[m] = nil end
    local old=package.path; package.path=d..'/?.lua;'..d..'/../?.lua;'
    local ret = require_(m); package.path=old
    return ret
  end
end)()

local luaunit = require('luaunit', { force = true })
local paths = require("paths", { force = true })

TestPathUtils = {}

function TestPathUtils:test_sep()
    luaunit.assertStrMatches(paths.sep(), '[\\/]')
end

local ret = luaunit.LuaUnit.run()
if not vim or not vim.fn then
  os.exit(ret)
end
